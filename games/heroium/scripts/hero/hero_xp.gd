class_name HeroXp
extends Node

## Experienta si nivelul dintr-o singura rulare.
##
## Nivelul e ceea ce se pierde la moarte - el aduce cartile de abilitati, adica
## puterea care se construieste intr-o rulare. Ce ramane intre rulari sunt
## talentele din Calea Legendara, si stau in alta parte (GameState).

signal changed(level: int, current: float, needed: float)
signal leveled_up(level: int)

## Cat cere primul nivel.
const FIRST_LEVEL_COST := 8.0
## Cu cat se scumpeste fiecare nivel urmator.
const COST_PER_LEVEL := 4.5

var level: int = 1
var current: float = 0.0
var needed: float = FIRST_LEVEL_COST


func _ready() -> void:
	changed.emit(level, current, needed)


func add(amount: float) -> void:
	if amount <= 0.0:
		return

	current += amount
	# Un singur ciob poate trece doua niveluri odata; fiecare isi cere cartile,
	# iar ecranul de nivel le ia la rand.
	while current >= needed:
		current -= needed
		level += 1
		needed = roundf(FIRST_LEVEL_COST + float(level) * COST_PER_LEVEL)
		leveled_up.emit(level)

	changed.emit(level, current, needed)


func reset() -> void:
	level = 1
	current = 0.0
	needed = FIRST_LEVEL_COST
	changed.emit(level, current, needed)
