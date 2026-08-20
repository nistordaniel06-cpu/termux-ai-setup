class_name ParticleField
extends Node2D

## Toate scanteile din lume, tinute si desenate de un singur nod.
##
## Un nod per particula ar fi varianta simpla si cea scumpa: la cateva sute de
## scantei pe telefon se simte imediat. Aici sunt doar date intr-un vector,
## desenate intr-o singura trecere.

## Peste atat, cele mai vechi se pierd. Mai bine scapa cateva scantei decat sa
## se blocheze imaginea cand mor zece inamici odata.
const MAX_SPARKS := 260


class Spark:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var max_life: float
	var color: Color
	var radius: float


var _sparks: Array[Spark] = []


func _ready() -> void:
	set_process(false)
	# Scanteile continua sa se stinga peste podea, sub personaje.
	z_index = -1


func emit(at: Vector2, color: Color, count: int, speed: float = 130.0) -> void:
	for i in count:
		if _sparks.size() >= MAX_SPARKS:
			_sparks.pop_front()

		var spark := Spark.new()
		var angle := randf() * TAU
		var magnitude := speed * randf_range(0.35, 1.15)
		spark.position = at
		spark.velocity = Vector2.RIGHT.rotated(angle) * magnitude
		spark.max_life = randf_range(0.3, 0.6)
		spark.life = spark.max_life
		spark.color = color
		spark.radius = randf_range(1.6, 4.0)
		_sparks.append(spark)

	set_process(true)


func _process(delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[i]
		spark.life -= delta
		if spark.life <= 0.0:
			_sparks.remove_at(i)
			continue
		spark.position += spark.velocity * delta
		# Frecare, ca scanteile sa se aseze in loc sa zboare drept la infinit.
		spark.velocity *= 1.0 - minf(1.0, 3.2 * delta)

	queue_redraw()
	if _sparks.is_empty():
		set_process(false)


func _draw() -> void:
	for spark in _sparks:
		var fade := spark.life / spark.max_life
		var color := spark.color
		color.a *= fade
		draw_circle(spark.position, spark.radius * fade, color)
