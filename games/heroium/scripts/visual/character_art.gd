class_name CharacterArt
extends Node2D

## Corpul vizibil al unui personaj, desenat in cod - dar ca personaj, nu ca bulina.
##
## Fiecare siluetă e construită din cateva forme in spatiu normalizat (-1..1),
## inmultite cu `radius`. Asa un schelet si un sef de trei ori mai mare folosesc
## acelasi desen, iar o marime noua nu cere nimic in plus.
##
## De ce desenat si nu texturi: un Sprite2D fara textura nu deseneaza nimic si
## nu se plange, iar jocul a stat odata complet gri exact din motivul asta.
## Formele desenate se vad intotdeauna. Cand apare arta adevarata, nodul asta se
## inlocuieste cu un Sprite2D si nimic altceva nu se schimba.

enum Silhouette {
	HERO,       ## arcas cu gluga si pelerina
	SKELETON,   ## craniu si coaste
	BAT,        ## trup mic si aripi care bat
	CULTIST,    ## roba cu gluga, ochi aprinsi
	DEMON,      ## indesat, cu coarne
	KNIGHT,     ## coif cu viziera si umeri lati
	COLOSSUS,   ## schelet urias, cu coarne de os
	KING,       ## coroana si pelerina - seful final
}

## Cat tine licarirea alba de la o lovitura.
const FLASH_TIME := 0.18

@export var silhouette: Silhouette = Silhouette.SKELETON:
	set(value):
		silhouette = value
		_refresh()
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
@export var outline_width: float = 2.5

var _flash: float = 0.0
var _age: float = 0.0
## Fiecare personaj se leagana putin decalat, altfel o camera intreaga ar respira
## la unison si ar arata a mecanism, nu a multime.
var _offset: float = 0.0


func _ready() -> void:
	_offset = randf() * TAU


func _process(delta: float) -> void:
	_age += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()


## Licarire alba la impact - singurul semn ca lovitura a contat.
func flash() -> void:
	_flash = FLASH_TIME
	queue_redraw()


func _refresh() -> void:
	if is_node_ready():
		queue_redraw()


## Culoarea corpului acum, cu licarirea aplicata.
func _body_color() -> Color:
	return fill.lerp(Color.WHITE, _flash / FLASH_TIME)


func _draw() -> void:
	# Legănarea si umbra sunt aceleasi pentru toti; ce difera e silueta.
	var bob := sin(_age * 2.6 + _offset) * radius * 0.05
	draw_circle(Vector2(0.0, radius * 0.46), radius * 0.82, Color(0.0, 0.0, 0.0, 0.28))

	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	match silhouette:
		Silhouette.HERO:
			_draw_hero()
		Silhouette.BAT:
			_draw_bat()
		Silhouette.CULTIST:
			_draw_cultist()
		Silhouette.DEMON:
			_draw_demon()
		Silhouette.KNIGHT:
			_draw_knight()
		Silhouette.COLOSSUS:
			_draw_skeleton(true)
		Silhouette.KING:
			_draw_king()
		_:
			_draw_skeleton(false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ====================== SILUETE ======================
# Toate lucreaza in unitati de `radius`, deci scaleaza singure.

func _poly(points: PackedVector2Array, color: Color) -> void:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * radius)
	draw_colored_polygon(scaled, color)
	# Conturul inchide forma si o desprinde de fundal.
	scaled.append(scaled[0])
	draw_polyline(scaled, outline, outline_width, true)


func _dot(at: Vector2, size: float, color: Color) -> void:
	draw_circle(at * radius, size * radius, color)


## Ochii aprinsi sunt cel mai ieftin mod de a face o forma sa para vie.
func _eyes(y: float, spread: float, size: float, color: Color) -> void:
	_dot(Vector2(-spread, y), size, color)
	_dot(Vector2(spread, y), size, color)


func _draw_hero() -> void:
	var body := _body_color()
	# Pelerina: mai lata jos, ca sa citeasca a om in miscare.
	_poly(PackedVector2Array([
		Vector2(-0.34, -0.30), Vector2(0.34, -0.30),
		Vector2(0.62, 0.86), Vector2(-0.62, 0.86),
	]), body.darkened(0.28))
	# Gluga
	_poly(PackedVector2Array([
		Vector2(-0.40, -0.24), Vector2(0.0, -0.92), Vector2(0.40, -0.24),
	]), body)
	# Umbra sub gluga, si ochii in ea
	draw_circle(Vector2(0.0, -0.34) * radius, 0.24 * radius, Color(0.05, 0.04, 0.09))
	_eyes(-0.36, 0.11, 0.045, Color(1.0, 0.93, 0.72))


func _draw_skeleton(is_giant: bool) -> void:
	var bone := _body_color()
	# Trup ingust: un schelet nu are carne.
	_poly(PackedVector2Array([
		Vector2(-0.30, -0.14), Vector2(0.30, -0.14),
		Vector2(0.40, 0.84), Vector2(-0.40, 0.84),
	]), bone.darkened(0.15))

	# Coaste
	for i in 3:
		var y := (-0.02 + float(i) * 0.20) * radius
		draw_line(Vector2(-0.26 * radius, y), Vector2(0.26 * radius, y), outline, outline_width * 0.7)

	# Craniu
	draw_circle(Vector2(0.0, -0.44) * radius, 0.38 * radius, bone)
	draw_arc(Vector2(0.0, -0.44) * radius, 0.38 * radius, 0.0, TAU, 20, outline, outline_width, true)
	_eyes(-0.48, 0.15, 0.075, Color(0.05, 0.03, 0.08))

	if is_giant:
		# Colosul poarta coarne de os - se vede de departe ca nu e un schelet oarecare.
		_poly(PackedVector2Array([
			Vector2(-0.36, -0.62), Vector2(-0.70, -1.02), Vector2(-0.20, -0.76),
		]), bone)
		_poly(PackedVector2Array([
			Vector2(0.36, -0.62), Vector2(0.70, -1.02), Vector2(0.20, -0.76),
		]), bone)


func _draw_bat() -> void:
	var body := _body_color()
	# Aripile bat; unghiul lor e singura miscare care conteaza la un liliac.
	var flap := sin(_age * 11.0 + _offset) * 0.34
	for side in [-1.0, 1.0]:
		_poly(PackedVector2Array([
			Vector2(side * 0.18, -0.06),
			Vector2(side * 1.10, -0.40 + flap),
			Vector2(side * 0.98, 0.16 + flap * 0.6),
			Vector2(side * 0.30, 0.26),
		]), body.darkened(0.2))

	draw_circle(Vector2.ZERO, 0.42 * radius, body)
	draw_arc(Vector2.ZERO, 0.42 * radius, 0.0, TAU, 18, outline, outline_width, true)
	# Urechi
	_poly(PackedVector2Array([Vector2(-0.30, -0.30), Vector2(-0.16, -0.78), Vector2(-0.02, -0.34)]), body)
	_poly(PackedVector2Array([Vector2(0.30, -0.30), Vector2(0.16, -0.78), Vector2(0.02, -0.34)]), body)
	_eyes(-0.06, 0.14, 0.06, Color(1.0, 0.85, 0.4))


func _draw_cultist() -> void:
	var robe := _body_color()
	_poly(PackedVector2Array([
		Vector2(-0.30, -0.34), Vector2(0.30, -0.34),
		Vector2(0.56, 0.88), Vector2(-0.56, 0.88),
	]), robe.darkened(0.3))
	# Gluga ascutita
	_poly(PackedVector2Array([
		Vector2(-0.38, -0.28), Vector2(0.0, -1.00), Vector2(0.38, -0.28),
	]), robe)
	draw_circle(Vector2(0.0, -0.38) * radius, 0.22 * radius, Color(0.04, 0.02, 0.07))
	# Ochii pulseaza: e singurul care trage, deci merita sa fie cel mai vizibil.
	var glow := 0.75 + sin(_age * 4.0 + _offset) * 0.25
	_eyes(-0.40, 0.10, 0.05, Color(0.85, 0.45, 1.0, glow))


func _draw_demon() -> void:
	var hide := _body_color()
	_poly(PackedVector2Array([
		Vector2(-0.52, -0.18), Vector2(0.52, -0.18),
		Vector2(0.66, 0.84), Vector2(-0.66, 0.84),
	]), hide.darkened(0.18))
	draw_circle(Vector2(0.0, -0.40) * radius, 0.42 * radius, hide)
	draw_arc(Vector2(0.0, -0.40) * radius, 0.42 * radius, 0.0, TAU, 20, outline, outline_width, true)
	# Coarne
	_poly(PackedVector2Array([Vector2(-0.40, -0.56), Vector2(-0.74, -1.06), Vector2(-0.14, -0.72)]), hide.lightened(0.1))
	_poly(PackedVector2Array([Vector2(0.40, -0.56), Vector2(0.74, -1.06), Vector2(0.14, -0.72)]), hide.lightened(0.1))
	_eyes(-0.44, 0.16, 0.07, Color(1.0, 0.85, 0.3))


func _draw_knight() -> void:
	var steel := _body_color()
	# Umeri lati: silueta unui zid care merge.
	_poly(PackedVector2Array([
		Vector2(-0.68, -0.10), Vector2(0.68, -0.10),
		Vector2(0.58, 0.86), Vector2(-0.58, 0.86),
	]), steel.darkened(0.22))
	# Coif
	_poly(PackedVector2Array([
		Vector2(-0.38, -0.30), Vector2(-0.30, -0.86), Vector2(0.30, -0.86), Vector2(0.38, -0.30),
	]), steel)
	# Viziera - o singura fanta, si de aceea infricosatoare
	draw_rect(Rect2(Vector2(-0.30, -0.62) * radius, Vector2(0.60, 0.13) * radius), Color(0.04, 0.03, 0.08))
	draw_rect(Rect2(Vector2(-0.22, -0.60) * radius, Vector2(0.44, 0.07) * radius), Color(1.0, 0.72, 0.35, 0.85))


func _draw_king() -> void:
	var cloth := _body_color()
	# Pelerina lunga
	_poly(PackedVector2Array([
		Vector2(-0.44, -0.26), Vector2(0.44, -0.26),
		Vector2(0.80, 0.90), Vector2(-0.80, 0.90),
	]), cloth.darkened(0.34))
	# Trup
	_poly(PackedVector2Array([
		Vector2(-0.34, -0.24), Vector2(0.34, -0.24),
		Vector2(0.42, 0.72), Vector2(-0.42, 0.72),
	]), cloth.darkened(0.1))
	# Cap
	draw_circle(Vector2(0.0, -0.44) * radius, 0.34 * radius, cloth.lightened(0.05))
	draw_arc(Vector2(0.0, -0.44) * radius, 0.34 * radius, 0.0, TAU, 20, outline, outline_width, true)
	_eyes(-0.46, 0.13, 0.06, Color(0.6, 0.95, 1.0))

	# Coroana: trei varfuri. E tot ce trebuie ca sa se citeasca "rege".
	var gold := Color("f0b45a")
	_poly(PackedVector2Array([
		Vector2(-0.40, -0.72), Vector2(-0.40, -1.02), Vector2(-0.20, -0.84),
		Vector2(0.0, -1.10), Vector2(0.20, -0.84), Vector2(0.40, -1.02),
		Vector2(0.40, -0.72),
	]), gold)
