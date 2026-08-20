class_name XpOrb
extends Area2D

## Ciobul de experienta lasat de un inamic mort.
##
## De la o distanta il trage singur spre erou. Fara magnetul asta jucatorul ar
## trebui sa calce pe fiecare ciob, adica exact opusul a ce cere jocul: sa te
## misti dupa cum e periculos, nu dupa unde a cazut marunta.

## De la ce distanta incepe sa fie tras spre erou.
const MAGNET_RANGE := 150.0
const MAGNET_SPEED := 460.0
## Cat traieste daca nu-l ia nimeni - camerele lungi n-ar trebui sa adune cioburi.
const LIFETIME := 25.0

var xp: int = 2

var _hero: Node2D = null
var _age: float = 0.0
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_hero = get_tree().get_first_node_in_group(&"hero")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	if _hero == null or not is_instance_valid(_hero):
		return

	var to_hero := _hero.global_position - global_position
	var distance := to_hero.length()
	if distance < MAGNET_RANGE:
		# Cu cat e mai aproape, cu atat vine mai repede - ultimul salt e vizibil.
		var pull := 1.0 - (distance / MAGNET_RANGE)
		global_position += to_hero.normalized() * MAGNET_SPEED * pull * delta

	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group(&"hero"):
		return
	_collected = true

	if body.has_method(&"gain_xp"):
		body.gain_xp(xp)
	Fx.burst(global_position, Color("5ef0b6"), 5, 90.0)
	queue_free()


func _draw() -> void:
	# Pulseaza incet, ca sa se distinga de decor fara sa fure privirea.
	var pulse := 1.0 + sin(_age * 5.0) * 0.15
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color(0.36, 0.94, 0.71, 0.25))
	draw_circle(Vector2.ZERO, 4.0 * pulse, Color("5ef0b6"))
