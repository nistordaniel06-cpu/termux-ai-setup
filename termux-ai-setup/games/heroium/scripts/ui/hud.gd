extends Control

## Viata, monedele, camera curenta si ecranul de infrangere.
##
## Deseneaza tot in cod, cu fontul implicit al motorului: asa nu depinde de o
## tema sau de fonturi importate, si arata la fel pe telefon si pe Web.

## Distanta fata de marginile ecranului.
const MARGIN := 24.0
const BAR_HEIGHT := 24.0

@export var hero_path: NodePath
@export var arena_path: NodePath

var _hero: Hero = null
var _health: float = 0.0
var _max_health: float = 1.0
var _coins: int = 0
var _room: int = 1
var _dead: bool = false


func _ready() -> void:
	# HUD-ul acopera tot ecranul: daca ar prinde atingerile, joystick-ul de
	# dedesubt n-ar mai primi niciuna.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

	_coins = GameState.coins
	GameState.coins_changed.connect(_on_coins_changed)

	var arena := get_node_or_null(arena_path) as Arena
	if arena != null:
		_room = arena.room_index
		arena.room_cleared.connect(_on_room_cleared)

	_hero = get_node_or_null(hero_path) as Hero
	if _hero != null:
		_hero.health_changed.connect(_on_health_changed)
		_hero.died.connect(_on_hero_died)
		# Eroul e gata inaintea HUD-ului, deci semnalul initial a trecut deja.
		_on_health_changed(_hero.get_health(), _hero.get_max_health())


func _on_health_changed(current: float, maximum: float) -> void:
	_health = current
	_max_health = maxf(1.0, maximum)
	queue_redraw()


func _on_coins_changed(amount: int) -> void:
	_coins = amount
	queue_redraw()


func _on_room_cleared(index: int) -> void:
	_room = index + 1
	queue_redraw()


func _on_hero_died() -> void:
	_dead = true
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _dead:
		return

	var pressed: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
	)
	if not pressed:
		return

	# Arena a inghetat scena la moarte; fara dezghetare, si cea noua ar porni oprita.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var width := size.x - MARGIN * 2.0

	var bar := Rect2(MARGIN, MARGIN, width, BAR_HEIGHT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	var fraction := clampf(_health / _max_health, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), Color("e2574c"))
	draw_rect(bar, Color(1, 1, 1, 0.22), false, 2.0)
	draw_string(
		font,
		bar.position + Vector2(10.0, 17.0),
		"%d / %d" % [roundi(_health), roundi(_max_health)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.92)
	)

	var line := Vector2(MARGIN, bar.end.y + 26.0)
	draw_string(font, line, "Camera %d" % _room,
		HORIZONTAL_ALIGNMENT_LEFT, width, 18, Color("f0b45a"))
	draw_string(font, line, "%d monede" % _coins,
		HORIZONTAL_ALIGNMENT_RIGHT, width, 18, Color("f0b45a"))

	if _dead:
		_draw_defeat(font, width)


func _draw_defeat(font: Font, width: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.78))

	var middle := size.y * 0.5
	draw_string(font, Vector2(MARGIN, middle), "Ai căzut în camera %d" % _room,
		HORIZONTAL_ALIGNMENT_CENTER, width, 30, Color("f0b45a"))
	draw_string(font, Vector2(MARGIN, middle + 42.0), "Atinge ecranul ca să reîncerci",
		HORIZONTAL_ALIGNMENT_CENTER, width, 18, Color(1, 1, 1, 0.75))
