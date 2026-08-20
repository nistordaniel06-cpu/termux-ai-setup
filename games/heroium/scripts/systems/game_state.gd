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


func _ready() -> void:
	load_game()


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
	config.save(SAVE_PATH)


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	coins = config.get_value("progress", "coins", 0)
	total_rooms_cleared = config.get_value("progress", "total_rooms_cleared", 0)
	best_location = config.get_value("progress", "best_location", 1)
	talents = config.get_value("progress", "talents", {})
	var heroes: Array = config.get_value("progress", "unlocked_heroes", [&"ranger"])
	unlocked_heroes.assign(heroes)


## Sterge tot progresul. Doar pentru testare.
func wipe() -> void:
	coins = 0
	total_rooms_cleared = 0
	best_location = 1
	talents.clear()
	unlocked_heroes = [&"ranger"]
	save_game()
	coins_changed.emit(coins)
	talents_changed.emit()
