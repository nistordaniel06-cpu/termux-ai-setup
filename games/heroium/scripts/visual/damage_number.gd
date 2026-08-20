class_name DamageNumber
extends Node2D

## Cifra care sare din tinta la fiecare lovitura.
##
## Fara ea, o lupta e un schimb de licariri: vezi ca ai lovit, dar nu cat. Cu ea,
## diferenta dintre o abilitate buna si una slaba se citeste din prima camera, nu
## dupa trei rulari - si o critica se simte ca o critica.

const LIFETIME := 0.75
## Cat urca pana se stinge.
const RISE := 46.0

var amount: float = 0.0
var is_crit: bool = false

var _age: float = 0.0
var _drift: float = 0.0


static func create(at: Vector2, value: float, crit: bool) -> DamageNumber:
	var number := DamageNumber.new()
	number.position = at
	number.amount = value
	number.is_crit = crit
	return number


func _ready() -> void:
	# Deasupra tuturor: o cifra ascunsa sub un inamic nu spune nimic.
	z_index = 20
	# Imprastiere laterala mica, ca doua lovituri deodata sa nu se suprapuna.
	_drift = randf_range(-20.0, 20.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	# Radicalul o face sa urce repede si sa incetineasca: arata a saritura, nu a lift.
	var offset := Vector2(_drift * t, -RISE * sqrt(t))

	var color := Color("ffe9a3") if is_crit else Color("ffffff")
	color.a = 1.0 - t * t

	var size := 24 if is_crit else 17
	var text := "%d!" % roundi(amount) if is_crit else str(roundi(amount))

	# Latimea data cu aliniere la centru aseaza textul chiar peste tinta.
	var width := 90.0
	draw_string(
		ThemeDB.fallback_font, offset - Vector2(width * 0.5, 0.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, width, size, color
	)
