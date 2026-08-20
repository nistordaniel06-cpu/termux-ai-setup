extends SceneTree

## Testele lui Heroium. Se ruleaza fara interfata grafica, cu Godot 4.3:
##
##   godot --headless --path games/heroium --script res://tests/run_tests.gd
##
## Iese cu cod 1 daca ceva a picat, deci poate fi pus intr-un CI ca atare.
##
## ATENTIE: sterge progresul salvat (user://heroium_save.cfg) la inceput si la
## sfarsit, ca rezultatele sa nu depinda de cat a jucat cineva inainte.
##
## Nu verifica cum ARATA jocul - verifica lucrurile care se pot strica in tacere:
## ca inamicii chiar apar, ca eroul chiar trage, ca fuziunea chiar are loc, ca
## talentele cumparate chiar se simt in rulare.

var failures := 0
var checks := 0


func _initialize() -> void:
	# Intr-un script de SceneTree, `_initialize` ruleaza inaintea lui `_ready` al
	# autoloadurilor - deci inainte ca GameState sa-si fi incarcat continutul. In
	# joc ordinea e invers (autoloadurile sunt gata primele), asa ca asteptam un
	# cadru si abia apoi ne uitam la el.
	await process_frame

	var state := root.get_node("GameState")
	state.wipe()

	await _test_content_loads(state)
	await _test_fusion()
	await _test_run_loop()
	await _test_enemy_behaviours()
	await _test_boss_room()
	await _test_defeat()
	await _test_legendary_path(state)
	await _test_heroes(state)
	await _test_boss_phases(state)
	await _test_game_modes(state)
	await _test_touch_reaches_buttons()
	await _test_looks(state)
	await _test_pooling()
	await _test_composable_effects(state)
	await _test_difficulty_scaling()

	state.wipe()

	print("")
	if failures == 0:
		print("REZULTAT: %d verificări, toate au trecut." % checks)
	else:
		print("REZULTAT: %d verificări, %d au picat." % [checks, failures])
	quit(1 if failures > 0 else 0)


# ====================== VERIFICARI ======================

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  OK   ", label, "  ", detail)
	else:
		failures += 1
		print("  PICAT ", label, "  ", detail)


## Cate noduri de un anumit fel sunt in lume. Merge dupa scriptul atasat, fiindca
## nodurile astea sunt toate Area2D si nu se pot deosebi dupa clasa nativa.
func _count_by_script(world: Node, script_name: String) -> int:
	var total := 0
	for child in world.get_children():
		var script = child.get_script()
		if script != null and script.resource_path.ends_with(script_name + ".gd"):
			total += 1
	return total


func _open_run() -> Node:
	paused = false
	var run: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(run)
	await process_frame
	return run


# ====================== TESTE ======================

func _test_content_loads(state: Node) -> void:
	print("\n[1] CONȚINUTUL SE ÎNCARCĂ")
	check("cele patru locații", state.locations.size() == 4, "%d" % state.locations.size())
	check("cele trei clase de erou", state.heroes.size() == 3, "%d" % state.heroes.size())
	check("pachetul de abilități", state.abilities.size() >= 10, "%d" % state.abilities.size())

	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	check("meniul se construiește", menu.get_child_count() > 0)
	menu.free()

	var castle: Location = state.location_at(1)
	check("varietatea crește prin locație",
		castle.available_types(1).size() < castle.available_types(9).size(),
		"%d feluri în camera 1, %d în camera 9"
			% [castle.available_types(1).size(), castle.available_types(9).size()])
	check("numărul de inamici crește",
		castle.enemy_count_for(1) < castle.enemy_count_for(9),
		"%d -> %d" % [castle.enemy_count_for(1), castle.enemy_count_for(9)])


func _test_fusion() -> void:
	print("\n[2] FUZIUNEA")
	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")

	var pierce: Ability = load("res://resources/abilities/piercing_arrow.tres")
	var meteor: Ability = load("res://resources/abilities/meteor_infernal.tres")

	hero.grant_ability(pierce)
	check("prima abilitate intră", hero.get_abilities().size() == 1)

	hero.grant_ability(meteor)
	var owned: Array[Ability] = hero.get_abilities()
	check("cele două se topesc într-una", owned.size() == 1, "%d în mână" % owned.size())
	check("rezultatul e Săgeată Explozivă",
		owned.size() == 1 and owned[0].id == &"explosive_arrow",
		owned[0].display_name if owned.size() == 1 else "-")
	check("evoluția nu se oferă direct la cărți",
		not pierce.fusion_result.is_draftable(99999))

	run.free()


func _test_run_loop() -> void:
	print("\n[3] BUCLA UNEI RULĂRI")
	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")

	check("prima locație e Pădurea",
		run.location != null and run.location.id == &"cursed_forest",
		run.location.display_name if run.location != null else "-")
	check("inamicii apar", get_nodes_in_group(&"enemy").size() > 0,
		"%d în camera 1" % get_nodes_in_group(&"enemy").size())

	var level_up := run.get_node("HUD/LevelUp")
	var picks := 0
	var saw_three_cards := false

	# Eroul stă pe loc, deci țintește și trage singur. Îi dăm timp să curețe.
	for step in 44:
		await create_timer(0.25).timeout
		if not level_up.visible:
			continue
		var cards: Array = level_up._rows.get_children()
		if picks == 0:
			saw_three_cards = cards.size() == 3
			check("jocul se oprește cât alegi", paused)
		if cards.size() > 0:
			cards[0].pressed.emit()
			picks += 1

	check("se oferă trei cărți", saw_three_cards)
	check("eroul urcă nivel", hero.get_level() > 1, "nivel %d" % hero.get_level())
	check("alegerile se aplică", hero.get_abilities().size() > 0,
		"%d abilități" % hero.get_abilities().size())
	check("camerele se curăță", run.rooms_cleared > 0, "%d camere" % run.rooms_cleared)
	check("monedele se adună", run.coins_earned > 0, "%d monede" % run.coins_earned)
	check("jocul repornește după alegere", not paused)

	run.free()


func _test_enemy_behaviours() -> void:
	print("\n[4] CUM SE POARTĂ INAMICII")
	var run := await _open_run()

	# Castelul Întunecat are și arcași, și năvălitori. Camera 6 le aduce pe toate.
	run._enter_location(1)
	run.room = 6
	run.rooms_cleared = 6
	run.build_room()
	await process_frame

	var behaviours := {}
	for enemy in get_nodes_in_group(&"enemy"):
		behaviours[enemy.type.behavior] = true
	check("apar feluri diferite de inamic", behaviours.size() >= 2,
		"%d feluri distincte" % behaviours.size())

	var world: Node = run.get_node("World")
	var telegraphed := false
	var shot := false
	for step in 40:
		await create_timer(0.1).timeout
		telegraphed = telegraphed or _count_by_script(world, "telegraph") > 0
		shot = shot or _count_by_script(world, "enemy_projectile") > 0
		if telegraphed and shot:
			break

	check("lovitura se anunță înainte să cadă", telegraphed)
	check("arcașii chiar trag", shot)

	run.free()


func _test_boss_room() -> void:
	print("\n[5] CAMERA ȘEFULUI")
	var run := await _open_run()

	run._enter_location(0)
	# Așa se ajunge la șeful pădurii în joc: după cele 7 camere dinaintea lui.
	run.room = run.location.rooms
	run.rooms_cleared = 7
	run.build_room()
	await process_frame

	var enemies := get_nodes_in_group(&"enemy")
	check("în camera șefului e un singur inamic", enemies.size() == 1, "%d" % enemies.size())
	check("și acela e șef", enemies.size() == 1 and enemies[0].type.is_boss,
		enemies[0].type.display_name if enemies.size() == 1 else "-")
	# 300 de bază + 70 pe treaptă x 7 camere = 790.
	check("viața șefului crește cu treapta",
		enemies.size() == 1 and enemies[0].max_health > 700.0,
		"%d viață" % enemies[0].max_health if enemies.size() == 1 else "-")

	run.free()


func _test_defeat() -> void:
	print("\n[6] SFÂRȘITUL RULĂRII")
	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")
	var game_over := run.get_node("HUD/GameOver")

	check("ecranul de final e ascuns la început", not game_over.visible)

	hero.take_damage(999999.0)
	await process_frame
	await process_frame

	check("rularea e marcată încheiată", run.is_over)
	check("ecranul de final apare", game_over.visible)
	check("jocul e oprit", paused)

	paused = false
	run.free()


func _test_legendary_path(state: Node) -> void:
	print("\n[7] CALEA LEGENDARĂ")
	state.wipe()

	check("pornești fără talente", state.talent_level(&"attack_power") == 0)
	check("rădăcina e disponibilă", state.is_talent_available(&"attack_power"))
	check("ramura e închisă la început", not state.is_talent_available(&"resistance"))
	check("fără monede nu poți cumpăra", not state.can_buy_talent(&"attack_power"))

	state.add_coins(5000)
	var before: int = state.coins
	var cost: int = state.talent_cost(&"attack_power")
	check("cumpărarea reușește", state.buy_talent(&"attack_power"))
	check("monedele scad cu exact prețul", state.coins == before - cost,
		"%d -> %d (preț %d)" % [before, state.coins, cost])
	check("ramura se deschide după rădăcină", state.is_talent_available(&"resistance"))
	check("nivelul următor costă mai mult", state.talent_cost(&"attack_power") > cost,
		"%d -> %d" % [cost, state.talent_cost(&"attack_power")])

	for i in 4:
		state.buy_talent(&"attack_power")
	check("cinci niveluri cumpărate", state.talent_level(&"attack_power") == 5)

	# Ranger are 125 atac de bază; cinci niveluri de Putere Atac dau +4% fiecare.
	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")
	var expected := 125.0 * (1.0 + 5 * 0.04)
	check("talentele se simt în rulare", absf(hero.stats.attack - expected) < 0.5,
		"atac %.1f (așteptat %.1f, bază 125)" % [hero.stats.attack, expected])
	run.free()


func _test_heroes(state: Node) -> void:
	print("\n[8] EROII")
	check("Knight e blocat la început", not state.is_hero_unlocked(&"knight"))
	check("alegerea cade pe Ranger", state.selected_hero_class().id == &"ranger")

	var knight: HeroClass = state.hero_class_by_id(&"knight")
	state.add_coins(knight.unlock_cost)
	check("Knight se deblochează", state.unlock_hero(&"knight", knight.unlock_cost))

	state.select_hero(&"knight")
	check("Knight devine clasa aleasă", state.selected_hero_class().id == &"knight")

	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")
	check("intri chiar cu Knight", hero.hero_class.id == &"knight", hero.hero_class.display_name)
	check("Knight e mai rezistent decât Ranger", hero.stats.max_health > 900.0,
		"%d viață" % hero.stats.max_health)
	run.free()


func _test_boss_phases(state: Node) -> void:
	print("\n[9] ȘEFII ÎȘI SCHIMBĂ FAZA")
	state.select_mode(state.Mode.CAMPAIGN)
	var run := await _open_run()

	run._enter_location(0)
	run.room = run.location.rooms
	run.rooms_cleared = 7
	run.build_room()
	await process_frame

	var enemies := get_nodes_in_group(&"enemy")
	check("șeful a apărut", enemies.size() == 1, "%d inamici" % enemies.size())
	var boss = enemies[0]
	check("pornește în faza I", boss.phase == 1)

	var damage_before: float = boss.contact_damage
	var speed_before: float = boss.move_speed

	# Îl coborâm exact sub pragul lui, nu mai jos - altfel ar muri.
	var threshold: float = boss.max_health * boss.type.phase_two_at
	boss.take_damage(boss.health - threshold + 1.0)
	await process_frame

	check("trece în faza a II-a sub prag", boss.phase == 2,
		"viață %d din %d" % [boss.health, boss.max_health])
	check("lovește mai tare", boss.contact_damage > damage_before,
		"%.0f -> %.0f" % [damage_before, boss.contact_damage])
	check("se mișcă mai repede", boss.move_speed > speed_before,
		"%.0f -> %.0f" % [speed_before, boss.move_speed])

	# Ajutoarele intră deferat, deci le așteptăm un cadru.
	await process_frame
	await process_frame
	var after := get_nodes_in_group(&"enemy").size()
	check("cheamă ajutoare", after > 1, "%d inamici în cameră" % after)
	check("camera nu se încheie cât mai mișcă ceva", not run.is_over)

	# Cifrele de daună apar la lovitură, nu la ardere.
	var world: Node = run.get_node("World")
	check("lovitura scoate o cifră de daună", _count_by_script(world, "damage_number") > 0,
		"%d cifre" % _count_by_script(world, "damage_number"))

	run.free()


func _test_game_modes(state: Node) -> void:
	print("\n[10] REGIMURILE DE JOC")

	# Boss Rush: prima cameră e deja a unui șef.
	state.select_mode(state.Mode.BOSS_RUSH)
	check("regimul se salvează", state.selected_mode == state.Mode.BOSS_RUSH)
	var rush := await _open_run()
	await process_frame
	var first := get_nodes_in_group(&"enemy")
	check("Boss Rush: camera 1 e a unui șef", first.size() == 1 and first[0].type.is_boss,
		first[0].type.display_name if first.size() == 1 else "%d inamici" % first.size())
	rush.free()

	# Campanie: după ultima locație vine victoria, nu încă o cameră.
	state.select_mode(state.Mode.CAMPAIGN)
	var run := await _open_run()
	var victory := run.get_node("HUD/GameOver")
	var last: int = state.locations.size() - 1
	run._enter_location(last)
	run.room = run.location.rooms
	run.rooms_cleared = 30
	run.build_room()
	await process_frame

	check("suntem în ultima locație", run._is_last_location(), run.location.display_name)
	check("ecranul de final e încă ascuns", not victory.visible)

	for enemy in get_nodes_in_group(&"enemy"):
		enemy.take_damage(999999.0)
	# Camera se încheie după răgazul dintre camere.
	await create_timer(run.breather + 0.6).timeout

	check("campania se câștigă", run.is_over)
	check("ecranul de victorie apare", victory.visible)
	check("scrie VICTORIE, nu AI CĂZUT", victory._title.text == "VICTORIE", victory._title.text)

	paused = false
	run.free()

	# Supraviețuire nu se termină: ultima locație se reia.
	state.select_mode(state.Mode.SURVIVAL)
	var endless := await _open_run()
	endless._enter_location(last)
	endless.room = endless.location.rooms
	endless._go_to_next_room()
	await process_frame
	check("Supraviețuire continuă după ultima locație", not endless.is_over)
	endless.free()
	state.select_mode(state.Mode.CAMPAIGN)


func _test_touch_reaches_buttons() -> void:
	print("\n[11] ATINGEREA POATE AJUNGE LA BUTOANE")
	# Butoanele (Control) reactioneaza la evenimente de MOUSE. Pe telefon, o
	# atingere devine apasare doar daca emularea e pornita; cu ea oprita, niciun
	# buton din joc nu mai poate fi folosit - si exact asa a fost livrat odata.
	#
	# Lantul de input nu se poate incerca aici: fara afisaj, interfata nu
	# primeste nici macar evenimente de mouse, deci o atingere simulata ar pica
	# la fel si cand totul e in regula. Ce se poate pazi e setarea insasi, si
	# tocmai ea a fost schimbata gresit - dupa un printerr al addonului de
	# joystick, care e o sugestie, nu o cerinta.
	var from_touch: bool = ProjectSettings.get_setting(
		"input_devices/pointing/emulate_mouse_from_touch")
	var from_mouse: bool = ProjectSettings.get_setting(
		"input_devices/pointing/emulate_touch_from_mouse")

	check("atingerea devine apăsare (altfel butoanele sunt moarte pe telefon)", from_touch)
	check("mouse-ul trece drept atingere (joystick-ul merge și pe desktop)", from_mouse)


func _test_looks(state: Node) -> void:
	print("\n[12] CUM ARATĂ")

	# Fiecare fel de inamic trebuie sa se deosebeasca dintr-o privire. Culoarea
	# singura nu ajunge - un schelet si un demon rosu ar fi doua buline.
	var roster := [
		"skeleton_warrior", "skeleton_archer", "skeleton_mage", "undead_knight",
		"dark_priest", "demon", "elite_skeleton", "bat",
		"fallen_king", "lord_of_the_dead", "necromancer",
	]
	var seen := {}
	var missing := 0
	for id in roster:
		var type: EnemyType = load("res://resources/enemies/%s.tres" % id)
		if type == null or type.visual == null:
			missing += 1
			continue
		seen[type.visual.silhouette] = true
	check("tot rosterul se încarcă", missing == 0, "%d lipsă din %d" % [missing, roster.size()])
	check("siluetele sunt distincte", seen.size() >= 8, "%d siluete pentru %d inamici"
		% [seen.size(), roster.size()])

	# Cei trei sefi din brief exista si sunt sefi.
	for id in ["fallen_king", "lord_of_the_dead", "necromancer"]:
		var boss: EnemyType = load("res://resources/enemies/%s.tres" % id)
		check("%s e șef cu fază a II-a" % boss.display_name,
			boss.is_boss and boss.phase_two_at > 0.0 and boss.summons != null)

	await _test_art_is_swappable()
	await _test_skins(state)


## Dovada ca arta finala se poate pune fara sa se atinga cod: aceeasi vedere,
## trei descrieri, trei noduri diferite dedesubt.
func _test_art_is_swappable() -> void:
	var holder := Node2D.new()
	root.add_child(holder)

	var drawn := CharacterVisual.new()
	drawn.silhouette = CharacterArt.Silhouette.SKELETON
	var view_drawn := CharacterBodyView.new()
	holder.add_child(view_drawn)
	view_drawn.apply(drawn, 16.0)
	await process_frame
	check("fără artă -> siluetă desenată", view_drawn.get_child(0) is CharacterArt,
		view_drawn.get_child(0).get_class())

	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	var still := CharacterVisual.new()
	still.texture = ImageTexture.create_from_image(image)
	var view_still := CharacterBodyView.new()
	holder.add_child(view_still)
	view_still.apply(still, 16.0)
	await process_frame
	check("cu textură -> Sprite2D", view_still.get_child(0) is Sprite2D,
		view_still.get_child(0).get_class())

	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", ImageTexture.create_from_image(image))
	var moving := CharacterVisual.new()
	moving.sprite_frames = frames
	var view_moving := CharacterBodyView.new()
	holder.add_child(view_moving)
	view_moving.apply(moving, 16.0)
	await process_frame
	check("cu animație -> AnimatedSprite2D", view_moving.get_child(0) is AnimatedSprite2D,
		view_moving.get_child(0).get_class())

	# Arta se aseaza pe raza de coliziune, nu pe marimea fisierului.
	var sprite: Sprite2D = view_still.get_child(0)
	check("arta se scalează la raza corpului",
		is_equal_approx(sprite.scale.x, 1.0), "scală %.2f pentru 32px la rază 16" % sprite.scale.x)

	holder.free()


func _test_skins(state: Node) -> void:
	state.wipe()
	check("pornești cu o singură înfățișare", state.unlocked_skins.size() == 1,
		"%d deblocate" % state.unlocked_skins.size())

	var void_skin: HeroSkin = state.skin_by_id(&"void")
	check("Umbra Regelui e blocată", not state.is_skin_unlocked(&"void"))
	check("fără monede nu se cumpără", not state.unlock_skin(&"void", void_skin.cost))

	state.add_coins(void_skin.cost)
	check("cu monede se cumpără", state.unlock_skin(&"void", void_skin.cost))
	state.select_skin(&"void")

	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")
	var view: CharacterBodyView = hero.get_node("Body")
	check("eroul poartă culoarea aleasă",
		view.visual != null and view.visual.tint.is_equal_approx(void_skin.color),
		str(view.visual.tint) if view.visual != null else "fără visual")

	var ranger: HeroClass = state.hero_class_by_id(&"ranger")
	check("înfățișarea nu schimbă nicio statistică",
		is_equal_approx(hero.stats.attack, ranger.stats.base_attack),
		"atac %.0f, bază %.0f" % [hero.stats.attack, ranger.stats.base_attack])
	check("culoarea aleasă nu se scrie în resursa clasei",
		ranger.visual.tint.is_equal_approx(ranger.accent_color),
		"clasa a rămas %s" % ranger.visual.tint)

	run.free()
	state.wipe()


func _test_composable_effects(state: Node) -> void:
	print("\n[13] EFECTE COMPOZABILE")

	# Cele cinci care nu se puteau exprima in modelul vechi de Ability.
	for id in ["frost_projectiles", "lightning_chain", "vampirism",
			"projectile_size", "projectile_speed"]:
		var ability: Ability = load("res://resources/abilities/%s.tres" % id)
		check("%s se încarcă cu efectul lui" % ability.display_name,
			ability.effects.size() == 1, "%d efecte" % ability.effects.size())

	# Doua abilitati luate impreuna isi aduna efectele fara cod scris pentru
	# perechea aceea anume - exact ce trebuia sa rezolve sistemul.
	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")
	var frost: Ability = load("res://resources/abilities/frost_projectiles.tres")
	var vamp: Ability = load("res://resources/abilities/vampirism.tres")
	hero.grant_ability(frost)
	hero.grant_ability(vamp)

	var combat: HeroCombat = hero.get_node("Combat")
	var collected := combat._collect_on_hit_effects()
	check("ambele efecte ajung la proiectil", collected.size() == 2, "%d efecte" % collected.size())

	# Frost incetineste si arde - se vede pe un inamic real, nu doar pe hartie.
	var enemy: Enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	var skeleton: EnemyType = load("res://resources/enemies/skeleton_warrior.tres")
	enemy.setup(skeleton, 0)
	run.get_node("World").add_child(enemy)
	await process_frame

	var before_speed := enemy.move_speed
	enemy.apply_frost(5.0, 0.4, 1.0)
	check("îngheț: viteza scade", enemy._current_speed() < before_speed,
		"%.0f -> %.0f" % [before_speed, enemy._current_speed()])
	var before_health := enemy.health
	await create_timer(0.3).timeout
	check("îngheț: arde în timp", enemy.health < before_health,
		"%.1f -> %.1f" % [before_health, enemy.health])

	# Vampirism: eroul se vindeca dupa o lovitura, proportional cu dauna.
	hero.take_damage(hero.get_max_health() * 0.5)
	var health_before_hit: float = hero.get_health()
	var vamp_effect: EffectVampirism = vamp.effects[0]
	var info := HitInfo.create(enemy, 100.0, false)
	info.attacker = hero
	vamp_effect.on_hit(info)
	check("vampirism vindecă eroul", hero.get_health() > health_before_hit,
		"%.0f -> %.0f (12%% din 100 = 12)" % [health_before_hit, hero.get_health()])

	# Lightning Chain sare la un al doilea inamic din apropiere.
	var second: Enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	second.setup(skeleton, 0)
	run.get_node("World").add_child(second)
	second.global_position = enemy.global_position + Vector2(50, 0)
	await process_frame

	var chain: Ability = load("res://resources/abilities/lightning_chain.tres")
	var chain_effect: EffectLightningChain = chain.effects[0]
	var second_health_before := second.health
	var chain_info := HitInfo.create(enemy, 40.0, false)
	chain_effect.on_hit(chain_info)
	check("lanțul electric lovește și vecinul", second.health < second_health_before,
		"%.1f -> %.1f" % [second_health_before, second.health])

	# Marimea si viteza proiectilului chiar ajung pe proiectilul tras.
	var proj_size: Ability = load("res://resources/abilities/projectile_size.tres")
	var proj_speed: Ability = load("res://resources/abilities/projectile_speed.tres")
	hero.grant_ability(proj_size)
	hero.grant_ability(proj_speed)
	check("mărimea intră în statistici", hero.stats.projectile_scale > 1.0,
		"scală %.2f" % hero.stats.projectile_scale)
	check("viteza intră în statistici", hero.stats.projectile_speed_mult > 1.0,
		"multiplicator %.2f" % hero.stats.projectile_speed_mult)

	var projectile: Projectile = load("res://scenes/abilities/projectile.tscn").instantiate()
	run.get_node("World").add_child(projectile)
	projectile.launch(Vector2.RIGHT, hero.stats)
	check("proiectilul chiar e mai mare", projectile.scale.x > 1.0, "scală %.2f" % projectile.scale.x)
	check("proiectilul chiar e mai rapid", projectile.speed > 900.0, "viteză %.0f" % projectile.speed)

	run.free()


## Verifica ca Pool refoloseste nodurile si nu le distruge cand sunt eliberate.
func _test_pooling() -> void:
	print("[13] TEST POOLING")
	var start_idle := Pool.idle_count(preload("res://scenes/abilities/projectile.tscn"))
	print("  Idle projectiles at start: ", start_idle)

	# Acquire and release a projectile
	var parent := Node2D.new()
	root.add_child(parent)
	var projectile: Projectile = Pool.acquire(preload("res://scenes/abilities/projectile.tscn"), parent) as Projectile
	check("acquire returns Projectile", projectile != null)
	check("acquired projectile is in parent", projectile.get_parent() == parent)

	# At this point, idle count should not have increased (we took one out)
	var idle_after_acquire := Pool.idle_count(preload("res://scenes/abilities/projectile.tscn"))
	check("idle count unchanged by acquire", idle_after_acquire == start_idle)

	# Release it
	Pool.release(projectile)
	var idle_after_release := Pool.idle_count(preload("res://scenes/abilities/projectile.tscn"))
	check("idle count increased after release", idle_after_release == start_idle + 1, "was %d now %d" % [start_idle, idle_after_release])

	# Acquire again should reuse the same node
	var projectile2: Projectile = Pool.acquire(preload("res://scenes/abilities/projectile.tscn"), parent) as Projectile
	check("reacquire returns same Projectile", projectile2 == projectile, "first: %s, second: %s" % [projectile, projectile2])

	idle_after_acquire = Pool.idle_count(preload("res://scenes/abilities/projectile.tscn"))
	check("idle count back down after reacquire", idle_after_acquire == start_idle)

	# Test release is idempotent
	Pool.release(projectile2)
	Pool.release(projectile2)  # Second call should be no-op
	var idle_after_double_release := Pool.idle_count(preload("res://scenes/abilities/projectile.tscn"))
	check("double release is safe", idle_after_double_release == start_idle + 1)

	parent.queue_free()


## Controlul mai automatizat trebuie sa intareasca inamicii - RoomWave anunta
## fiecare nastere prin `enemy_spawned`, iar Arena asculta o singura data si
## aplica multiplicatorul acolo. Verificam legatura capat la capat, nu doar
## ca HeroControl.difficulty_multiplier() intoarce numere corecte pe hartie.
func _test_difficulty_scaling() -> void:
	print("\n[14] SCALAREA DUPĂ CONTROL")
	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")

	hero.set_control_mode(HeroControl.Mode.DUAL_STICK)
	run._enter_location(0)
	run.room = 1
	run.build_room()
	await process_frame

	var manual_enemies := get_nodes_in_group(&"enemy")
	check("controlul manual nu întărește inamicii", manual_enemies.size() > 0
		and manual_enemies[0].max_health == manual_enemies[0].type.health_at(run.rooms_cleared),
		"%.0f viață" % manual_enemies[0].max_health if manual_enemies.size() > 0 else "-")

	hero.set_control_mode(HeroControl.Mode.AUTO)
	run.build_room()
	await process_frame

	var auto_enemies := get_nodes_in_group(&"enemy")
	var expected: float = auto_enemies[0].type.health_at(run.rooms_cleared) * 1.45 if auto_enemies.size() > 0 else 0.0
	check("modul automat întărește inamicii", auto_enemies.size() > 0
		and absf(auto_enemies[0].max_health - expected) < 0.5,
		"%.0f viață, așteptam %.0f" % [auto_enemies[0].max_health, expected] if auto_enemies.size() > 0 else "-")

	run.free()
