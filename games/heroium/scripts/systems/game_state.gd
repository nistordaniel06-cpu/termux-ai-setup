extends Node

## Progresul care supravietuieste intre rulari (autoload: GameState).
##
## Aici stau monedele, talentele permanente din Calea Legendară si deblocarile.
## Regula de baza a genului: ce se pierde la moarte e doar rularea; talentele si
## deblocarile raman, ca fiecare incercare sa lase ceva in urma.

signal coins_changed(amount: int)
signal talents_changed
signal hero_unlocked(hero_id: StringName)

const SAVE_PATH := "user://heroium_save.cfg"

## Locatiile campaniei, in ordinea in care se parcurg. Lista e explicita, nu
## citita din folder: intr-un build exportat listarea unui director nu e de
## incredere, si ordinea aici chiar conteaza.
const LOCATION_PATHS := [
	"res://resources/locations/cursed_forest.tres",
	"res://resources/locations/dark_castle.tres",
	"res://resources/locations/lost_desert.tres",
	"res://resources/locations/shadow_realm.tres",
]

## Tot ce se poate trage la carti cand urci un nivel. Evolutiile (Săgeată
## Explozivă) sunt si ele aici, dar isi poarta singure steagul care le tine
## afara din pachet - se obtin doar fuzionand.
const ABILITY_PATHS := [
	"res://resources/abilities/twin_arrows.tres",
	"res://resources/abilities/piercing_arrow.tres",
	"res://resources/abilities/meteor_infernal.tres",
	"res://resources/abilities/explosive_arrow.tres",
	"res://resources/abilities/ricochet.tres",
	"res://resources/abilities/sharp_tip.tres",
	"res://resources/abilities/rapid_fire.tres",
	"res://resources/abilities/light_step.tres",
	"res://resources/abilities/vitality.tres",
	"res://resources/abilities/bandages.tres",
	"res://resources/abilities/explosive_end.tres",
]

## Clasele de erou, in ordinea in care apar in meniu.
const HERO_PATHS := [
	"res://resources/heroes/ranger.tres",
	"res://resources/heroes/knight.tres",
	"res://resources/heroes/mage.tres",
]

var locations: Array[Location] = []
var abilities: Array[Ability] = []
var heroes: Array[HeroClass] = []
var selected_hero: StringName = &"ranger"

## Calea Legendară din poza: doua ramuri care pornesc din Putere Atac.
const TALENTS := {
	&"attack_power":  {"name": "Putere Atac",     "max": 10, "cost": 60,  "step": 0.04, "requires": &""},
	&"resistance":    {"name": "Rezistență",      "max": 8,  "cost": 80,  "step": 25.0, "requires": &"attack_power"},
	&"max_health":    {"name": "Sănătate Maximă", "max": 10, "cost": 70,  "step": 0.05, "requires": &"attack_power"},
	&"attack_speed":  {"name": "Viteză Atac",     "max": 8,  "cost": 90,  "step": 0.03, "requires": &"attack_power"},
	&"crit_chance":   {"name": "Șansă Critică",   "max": 6,  "cost": 120, "step": 0.02, "requires": &"attack_speed"},
}

var coins: int = 0
var total_rooms_cleared: int = 0
var best_location: int = 1
var talents: Dictionary = {}
var unlocked_heroes: Array[StringName] = [&"ranger"]


## Cea mai departe camera atinsa vreodata, ca ecranul de final sa aiba de ce sa
## se agate cand rularea a fost slaba.
var best_run_rooms: int = 0


func _ready() -> void:
	for path in LOCATION_PATHS:
		var location := load(path) as Location
		if location != null:
			locations.append(location)

	for path in ABILITY_PATHS:
		var ability := load(path) as Ability
		if ability != null:
			abilities.append(ability)

	for path in HERO_PATHS:
		var hero := load(path) as HeroClass
		if hero != null:
			heroes.append(hero)

	load_game()


## Locatia de la indicele dat. Dupa ultima campania nu se termina - se reia
## ultima locatie, dar inamicii cresc mai departe cu treapta, deci "endless"
## nu inseamna "aceeasi dificultate la nesfarsit".
func location_at(index: int) -> Location:
	if locations.is_empty():
		return null
	return locations[mini(index, locations.size() - 1)]


## Abilitatile care au voie sa apara la carti acum.
func draftable_abilities() -> Array[Ability]:
	var pool: Array[Ability] = []
	for ability in abilities:
		if ability.is_draftable(total_rooms_cleared):
			pool.append(ability)
	return pool


func register_run_result(rooms_this_run: int) -> void:
	best_run_rooms = maxi(best_run_rooms, rooms_this_run)
	save_game()


func talent_level(id: StringName) -> int:
	return talents.get(id, 0)


## Un talent e disponibil doar daca parintele lui are macar un nivel.
func is_talent_available(id: StringName) -> bool:
	var data: Dictionary = TALENTS.get(id, {})
	if data.is_empty():
		return false
	var requires: StringName = data.get("requires", &"")
	return requires == &"" or talent_level(requires) > 0


func talent_cost(id: StringName) -> int:
	var data: Dictionary = TALENTS.get(id, {})
	if data.is_empty():
		return 0
	# Fiecare nivel costa cu 35% mai mult decat precedentul.
	return int(round(data["cost"] * pow(1.35, talent_level(id))))


func can_buy_talent(id: StringName) -> bool:
	var data: Dictionary = TALENTS.get(id, {})
	if data.is_empty() or not is_talent_available(id):
		return false
	if talent_level(id) >= int(data["max"]):
		return false
	return coins >= talent_cost(id)


func buy_talent(id: StringName) -> bool:
	if not can_buy_talent(id):
		return false
	add_coins(-talent_cost(id))
	talents[id] = talent_level(id) + 1
	talents_changed.emit()
	save_game()
	return true


## Aplica talentele peste statisticile unei rulari noi.
func apply_talents(stats: HeroStats) -> void:
	stats.mult_attack *= 1.0 + talent_level(&"attack_power") * TALENTS[&"attack_power"]["step"]
	stats.bonus_defense += talent_level(&"resistance") * TALENTS[&"resistance"]["step"]
	stats.mult_health *= 1.0 + talent_level(&"max_health") * TALENTS[&"max_health"]["step"]
	stats.mult_attack_speed *= 1.0 + talent_level(&"attack_speed") * TALENTS[&"attack_speed"]["step"]
	stats.bonus_crit_chance += talent_level(&"crit_chance") * TALENTS[&"crit_chance"]["step"]
	stats.recalculate()


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)


func register_room_cleared() -> void:
	total_rooms_cleared += 1
	save_game()


func hero_class_by_id(id: StringName) -> HeroClass:
	for hero in heroes:
		if hero.id == id:
			return hero
	return null


## Clasa cu care se intra in temnita. Daca alegerea salvata nu mai e deblocata
## (sau nu mai exista), se cade inapoi pe Ranger, care e mereu al tau.
func selected_hero_class() -> HeroClass:
	var chosen := hero_class_by_id(selected_hero)
	if chosen != null and is_hero_unlocked(chosen.id):
		return chosen
	return hero_class_by_id(&"ranger")


func select_hero(id: StringName) -> void:
	if not is_hero_unlocked(id):
		return
	selected_hero = id
	save_game()


func is_hero_unlocked(id: StringName) -> bool:
	return id in unlocked_heroes


func unlock_hero(id: StringName, cost: int) -> bool:
	if is_hero_unlocked(id) or coins < cost:
		return false
	add_coins(-cost)
	unlocked_heroes.append(id)
	hero_unlocked.emit(id)
	save_game()
	return true


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "total_rooms_cleared", total_rooms_cleared)
	config.set_value("progress", "best_location", best_location)
	config.set_value("progress", "talents", talents)
	config.set_value("progress", "unlocked_heroes", unlocked_heroes)
	config.set_value("progress", "best_run_rooms", best_run_rooms)
	config.set_value("progress", "selected_hero", String(selected_hero))
	config.save(SAVE_PATH)


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	coins = config.get_value("progress", "coins", 0)
	total_rooms_cleared = config.get_value("progress", "total_rooms_cleared", 0)
	best_location = config.get_value("progress", "best_location", 1)
	talents = config.get_value("progress", "talents", {})
	best_run_rooms = config.get_value("progress", "best_run_rooms", 0)
	selected_hero = StringName(config.get_value("progress", "selected_hero", "ranger"))
	var saved_heroes: Array = config.get_value("progress", "unlocked_heroes", [&"ranger"])
	unlocked_heroes.assign(saved_heroes)


## Sterge tot progresul. Doar pentru testare.
func wipe() -> void:
	coins = 0
	total_rooms_cleared = 0
	best_location = 1
	best_run_rooms = 0
	talents.clear()
	selected_hero = &"ranger"
	unlocked_heroes = [&"ranger"]
	save_game()
	coins_changed.emit(coins)
	talents_changed.emit()
