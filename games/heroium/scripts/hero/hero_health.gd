class_name HeroHealth
extends Node

## Viata eroului, cu o scurta invulnerabilitate dupa fiecare lovitura.
##
## Fara acele cadre de gratie, doi inamici lipiti de erou l-ar goli instant si
## jucatorul n-ar avea cum sa reactioneze.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

const INVULNERABLE_TIME := 0.45

var maximum: float = 100.0
var current: float = 100.0
var is_dead: bool = false

var _invulnerable: float = 0.0


func setup(max_health: float) -> void:
	maximum = maxf(1.0, max_health)
	current = maximum
	is_dead = false
	_invulnerable = 0.0
	health_changed.emit(current, maximum)


func _process(delta: float) -> void:
	_invulnerable = maxf(0.0, _invulnerable - delta)


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


func take_damage(amount: float) -> void:
	if is_dead or is_invulnerable() or amount <= 0.0:
		return

	current = maxf(0.0, current - amount)
	_invulnerable = INVULNERABLE_TIME

	damaged.emit(amount)
	health_changed.emit(current, maximum)

	if current <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(maximum, current + amount)
	health_changed.emit(current, maximum)


## Ridica plafonul de viata. Bonusul vine si plin, nu doar ca potential: o carte
## care iti da viata maxima fara sa te vindece nu se simte ca o rasplata.
func increase_maximum(amount: float) -> void:
	if amount <= 0.0:
		return
	maximum += amount
	current += amount
	health_changed.emit(current, maximum)


## Foloseste "A doua torță": revine la o parte din viata, cu ragaz de gratie.
func revive(health_fraction: float = 0.5) -> void:
	is_dead = false
	current = maximum * clampf(health_fraction, 0.1, 1.0)
	_invulnerable = 1.6
	health_changed.emit(current, maximum)
