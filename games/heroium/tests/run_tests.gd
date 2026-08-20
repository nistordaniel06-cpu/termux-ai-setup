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

	# Fiecare fel de inamic trebuie să se deosebească dintr-o privire. Culoarea
	# singură nu ajunge - un schelet și un demon roșu ar fi două buline.
	var seen := {}
	for path in [
		"res://resources/enemies/skeleton.tres", "res://resources/enemies/bat.tres",
		"res://resources/enemies/cultist.tres", "res://resources/enemies/demon.tres",
		"res://resources/enemies/dread_knight.tres", "res://resources/enemies/bone_colossus.tres",
		"res://resources/enemies/fallen_king.tres",
	]:
		var type: EnemyType = load(path)
		seen[type.silhouette] = true
	check("cele șapte feluri au siluete distincte", seen.size() == 7, "%d siluete" % seen.size())

	# Skinuri
	state.wipe()
	check("pornești cu o singură înfățișare", state.unlocked_skins.size() == 1,
		"%d deblocate" % state.unlocked_skins.size())
	check("cea de start e purtată", state.selected_skin_resource().id == &"classic")

	var void_skin: HeroSkin = state.skin_by_id(&"void")
	check("Umbra Regelui e blocată", not state.is_skin_unlocked(&"void"))
	check("fără monede nu se cumpără", not state.unlock_skin(&"void", void_skin.cost))

	state.add_coins(void_skin.cost)
	check("cu monede se cumpără", state.unlock_skin(&"void", void_skin.cost))
	state.select_skin(&"void")
	check("devine purtată", state.selected_skin_resource().id == &"void")

	var run := await _open_run()
	var hero := get_first_node_in_group(&"hero")
	var body = hero.get_node("Body")
	check("eroul chiar poartă culoarea aleasă",
		body.fill.is_equal_approx(void_skin.color), str(body.fill))
	check("eroul are silueta de erou", body.silhouette == 0, "silueta %d" % body.silhouette)

	# Cosmeticul nu are voie sa atinga puterea.
	var ranger: HeroClass = state.hero_class_by_id(&"ranger")
	check("înfățișarea nu schimbă nicio statistică",
		is_equal_approx(hero.stats.attack, ranger.stats.base_attack),
		"atac %.0f, bază %.0f" % [hero.stats.attack, ranger.stats.base_attack])

	run.free()
	state.wipe()
