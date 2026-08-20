extends Node

## Efectele care se vad de peste tot: scantei, zguduit de camera, mesaje scurte.
##
## E autoload (Fx) tocmai ca inamicul, proiectilul si arena sa nu-si care fiecare
## propria referinta catre ele. Nu deseneaza el nimic - tine un camp de particule
## in lume si trimite mesajele mai departe printr-un semnal, pe care HUD-ul il
## asculta.

signal toast_requested(text: String)

var _field: ParticleField = null
var _camera: Camera2D = null
var _shake_time: float = 0.0
var _shake_magnitude: float = 0.0


## Arena leaga efectele de camera ei si de nodul in care au voie sa deseneze.
## Se re-cheama la fiecare reincarcare de scena: autoloadul supravietuieste, dar
## nodurile spre care arata nu.
func setup(world: Node2D, camera: Camera2D) -> void:
	_camera = camera
	_shake_time = 0.0
	_shake_magnitude = 0.0

	_field = ParticleField.new()
	_field.name = "ParticleField"
	world.add_child(_field)


func burst(at: Vector2, color: Color, count: int, speed: float = 130.0) -> void:
	if _field != null and is_instance_valid(_field):
		_field.emit(at, color, count, speed)


func shake(magnitude: float, duration: float) -> void:
	# Doua lovituri odata nu trebuie sa adune un cutremur: ramane cea mai tare.
	_shake_magnitude = maxf(_shake_magnitude, magnitude)
	_shake_time = maxf(_shake_time, duration)


func toast(text: String) -> void:
	toast_requested.emit(text)


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return

	if _shake_time <= 0.0:
		_camera.offset = Vector2.ZERO
		return

	_shake_time -= delta
	# Zguduitul se stinge spre final, altfel se opreste taiat.
	var falloff := clampf(_shake_time * 4.0, 0.0, 1.0)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
		* _shake_magnitude * falloff

	if _shake_time <= 0.0:
		_shake_magnitude = 0.0
		_camera.offset = Vector2.ZERO
