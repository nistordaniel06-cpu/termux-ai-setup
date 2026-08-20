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
