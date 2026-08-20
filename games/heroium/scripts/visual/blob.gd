class_name Blob
extends Node2D

## Corpul vizibil al unei entitati, desenat in cod.
##
## Jocul a pornit fara fisiere de arta, iar un Sprite2D fara textura nu
## deseneaza nimic - exact de acolo venea ecranul gri. Formele desenate se vad
## intotdeauna, se coloreaza per clasa si nu cer pipeline de import. Cand apare
## arta adevarata, nodul asta se inlocuieste cu un Sprite2D si nimic altceva
## nu se schimba.

## Cat tine licarirea alba de la o lovitura.
const FLASH_TIME := 0.18

@export var radius: float = 18.0:
	set(value):
		radius = value
		_refresh()
@export var fill: Color = Color("f0b45a"):
	set(value):
		fill = value
		_refresh()
@export var outline: Color = Color(0.04, 0.03, 0.07):
	set(value):
		outline = value
		_refresh()
@export var outline_width: float = 3.0

var _flash: float = 0.0


func _ready() -> void:
	set_process(false)


## Licarire alba la impact - singurul semn ca lovitura a contat.
func flash() -> void:
	_flash = FLASH_TIME
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)


func _draw() -> void:
	# Umbra de dedesubt desprinde forma de podea; fara ea totul pare lipit.
	draw_circle(Vector2(0.0, radius * 0.42), radius * 0.88, Color(0.0, 0.0, 0.0, 0.3))

	var body := fill.lerp(Color.WHITE, _flash / FLASH_TIME)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, outline, outline_width, true)

	# Reflexul din stanga-sus da volum unui simplu cerc.
	draw_circle(Vector2(-radius * 0.3, -radius * 0.34), radius * 0.24, Color(1, 1, 1, 0.26))


func _refresh() -> void:
	if is_node_ready():
		queue_redraw()
