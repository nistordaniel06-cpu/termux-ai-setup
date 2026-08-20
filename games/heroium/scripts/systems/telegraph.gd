class_name Telegraph
extends Node2D

## Semnul care apare inainte de o lovitura: cercul sub picioarele tale sau linia
## pe care va navali un inamic.
##
## E singurul lucru care face diferenta intre "greu" si "nedrept". Fara rabdarea
## asta de o fractiune de secunda, jucatorul n-are cum sa se fereasca de ceva ce
## nu vede venind, si moartea pare furata.

enum Kind { SPOT, LINE }

var kind: Kind = Kind.SPOT
var radius: float = 34.0
var target: Vector2 = Vector2.ZERO
var color: Color = Color(1.0, 0.35, 0.35)

var _life: float = 0.0
var _max_life: float = 0.75


## Cercul de sub tinta: "aici va cadea lovitura".
static func spot(at: Vector2, spot_radius: float, duration: float) -> Telegraph:
	var t := Telegraph.new()
	t.kind = Kind.SPOT
	t.position = at
	t.radius = spot_radius
	t._max_life = duration
	t._life = duration
	return t


## Linia de navala: "de aici pana aici, da-te la o parte".
static func line(from: Vector2, to: Vector2, duration: float) -> Telegraph:
	var t := Telegraph.new()
	t.kind = Kind.LINE
	t.position = from
	t.target = to
	t._max_life = duration
	t._life = duration
	return t


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# Se umple pe masura ce se apropie lovitura - progresul e citibil dintr-o
	# privire, fara sa fie nevoie sa numeri secunde.
	var progress := 1.0 - (_life / _max_life)

	var faint := color
	faint.a = 0.28
	var strong := color
	strong.a = 0.5 + progress * 0.45

	if kind == Kind.SPOT:
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, faint, 2.0, true)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, strong, 4.0, true)
		return

	# Linia porneste subtire si se ingroasa; la capat e lovitura.
	var local_target := target - global_position
	draw_line(Vector2.ZERO, local_target, Color(color.r, color.g, color.b, 0.14), 26.0)
	draw_line(Vector2.ZERO, local_target * progress, strong, 4.0 + progress * 5.0, true)
