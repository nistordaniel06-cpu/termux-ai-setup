class_name HeroStats
extends Resource

## Statisticile eroului pentru o singura rulare.
##
## Valoarea finala a fiecarei statistici se compune din trei straturi:
##   1. baza clasei (Ranger / Knight / Mage)
##   2. talentele permanente din Calea Legendara (raman intre rulari)
##   3. bonusurile din echipament si din abilitatile luate in rularea curenta
##
## Nimic nu scrie direct in valorile finale - se recalculeaza din straturi cu
## `recalculate()`, ca sa nu ramana bonusuri fantoma dupa ce expira un efect.

signal changed

@export_group("Bază")
@export var base_attack: float = 100.0
@export var base_health: float = 600.0
@export var base_defense: float = 40.0

@export_group("Luptă")
## Atacuri pe secunda, inainte de bonusuri.
@export var base_attack_speed: float = 1.6
@export_range(0.0, 1.0) var base_crit_chance: float = 0.05
@export var base_crit_multiplier: float = 2.0
## Cat de departe cauta eroul o tinta, in pixeli.
@export var base_range: float = 520.0

@export_group("Mișcare")
@export var base_move_speed: float = 260.0

# --- bonusuri aditive (talente, echipament, abilitati) ---
var bonus_attack: float = 0.0
var bonus_health: float = 0.0
var bonus_defense: float = 0.0
var bonus_attack_speed: float = 0.0
var bonus_crit_chance: float = 0.0
var bonus_move_speed: float = 0.0

# --- multiplicatori (procente din talente / abilitati) ---
var mult_attack: float = 1.0
var mult_health: float = 1.0
var mult_attack_speed: float = 1.0
var mult_move_speed: float = 1.0

# --- valorile finale, singurele citite de restul jocului ---
var attack: float = 0.0
var max_health: float = 0.0
var defense: float = 0.0
var attack_speed: float = 0.0
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0
var attack_range: float = 0.0
var move_speed: float = 0.0

## Numarul de proiectile trase odata (Săgeți Duble, Tir Triplu...).
var projectile_count: int = 1
## De cate ori mai poate trece un proiectil prin inamici.
var pierce: int = 0
## De cate ori ricoseaza din pereti.
var bounces: int = 0


func _init() -> void:
	recalculate()


## Reface valorile finale din straturi. De apelat dupa orice modificare.
func recalculate() -> void:
	attack = (base_attack + bonus_attack) * mult_attack
	max_health = (base_health + bonus_health) * mult_health
	defense = base_defense + bonus_defense
	attack_speed = maxf(0.1, (base_attack_speed + bonus_attack_speed) * mult_attack_speed)
	crit_chance = clampf(base_crit_chance + bonus_crit_chance, 0.0, 1.0)
	crit_multiplier = base_crit_multiplier
	attack_range = base_range
	move_speed = (base_move_speed + bonus_move_speed) * mult_move_speed
	changed.emit()


## Secundele dintre doua atacuri.
func attack_interval() -> float:
	return 1.0 / attack_speed


## Rostogoleste o lovitura: intoarce dauna si daca a fost critica.
## Apararea tintei reduce dauna procentual, nu fix - altfel inamicii tarzii
## ar deveni invulnerabili in loc de doar rezistenti.
func roll_damage(target_defense: float = 0.0) -> Dictionary:
	var is_crit := randf() < crit_chance
	var raw := attack * (crit_multiplier if is_crit else 1.0)
	var mitigation := target_defense / (target_defense + 400.0)
	return {
		"amount": maxf(1.0, raw * (1.0 - mitigation)),
		"crit": is_crit,
	}


## Copie proaspata, ca fiecare rulare sa porneasca de la zero.
func duplicate_for_run() -> HeroStats:
	var copy: HeroStats = duplicate(true)
	copy.recalculate()
	return copy
