extends Control

## Ce trebuie sa vezi fara sa cauti: viata, nivelul, experienta, monedele,
## unde esti si ce abilitati ai strans.
##
## Deseneaza tot in cod, cu fontul implicit al motorului - asa nu depinde de o
## tema sau de fonturi importate si arata la fel pe telefon si pe Web. Singurul
## nod adevarat e butonul de pauza, fiindca acela trebuie sa poata fi apasat.

signal pause_pressed

const MARGIN := 20.0
const HEALTH_HEIGHT := 22.0
const XP_HEIGHT := 10.0
## Cat sta pe ecran un mesaj scurt ("Castelul Întunecat", "Bătrânul Rege Căzut").
const TOAST_TIME := 1.8

@export var hero_path: NodePath
@export var arena_path: NodePath

var _hero: Hero = null

var _health: float = 0.0
var _max_health: float = 1.0
var _level: int = 1
var _xp: float = 0.0
var _xp_needed: float = 1.0
var _coins: int = 0
var _room: int = 1
var _location: String = ""
var _abilities: Array[Ability] = []
var _boss: Enemy = null

var _toast: String = ""
var _toast_left: float = 0.0


func _ready() -> void:
	# HUD-ul acopera tot ecranul: daca ar prinde atingerile, joystick-ul de
	# dedesubt n-ar mai primi niciuna. Copiii lui raman apasabili.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)

	_build_pause_button()

	_coins = GameState.coins
	GameState.coins_changed.connect(_on_coins_changed)
	Fx.toast_requested.connect(show_toast)

	var arena := get_node_or_null(arena_path) as Arena
	if arena != null:
		arena.room_started.connect(_on_room_started)
		arena.location_entered.connect(_on_location_entered)
		arena.boss_spawned.connect(_on_boss_spawned)

	_hero = get_node_or_null(hero_path) as Hero
	if _hero != null:
		_hero.health_changed.connect(_on_health_changed)
		_hero.xp_changed.connect(_on_xp_changed)
		_hero.ability_gained.connect(_on_abilities_changed)
		_hero.abilities_fused.connect(_on_abilities_fused)
		# Eroul e gata inaintea HUD-ului, deci semnalele initiale au trecut deja.
		_on_health_changed(_hero.get_health(), _hero.get_max_health())


func _build_pause_button() -> void:
	var pause := Button.new()
	pause.text = "❚❚"
	pause.custom_minimum_size = Vector2(52, 52)
	pause.position = Vector2(MARGIN, MARGIN + HEALTH_HEIGHT + XP_HEIGHT + 34.0)
	pause.focus_mode = Control.FOCUS_NONE
	pause.add_theme_font_size_override("font_size", 16)
	pause.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD_DIM, 12.0))
	pause.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD, 12.0))
	pause.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.PANEL, UiKit.GOLD, 12.0))
	pause.add_theme_color_override("font_color", UiKit.GOLD)
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause)


# ====================== DATE ======================

func _on_health_changed(current: float, maximum: float) -> void:
	_health = current
	_max_health = maxf(1.0, maximum)
	queue_redraw()


func _on_xp_changed(level: int, current: float, needed: float) -> void:
	_level = level
	_xp = current
	_xp_needed = maxf(1.0, needed)
	queue_redraw()


func _on_coins_changed(amount: int) -> void:
	_coins = amount
	queue_redraw()


func _on_room_started(room: int, is_boss: bool) -> void:
	_room = room
	if is_boss:
		show_toast("SEFUL LOCAȚIEI")
	queue_redraw()


func _on_location_entered(location: Location) -> void:
	_location = location.display_name
	queue_redraw()


func _on_abilities_changed(_ability: Ability) -> void:
	if _hero != null:
		_abilities = _hero.get_abilities()
	queue_redraw()


func _on_abilities_fused(_a: Ability, _b: Ability, result: Ability) -> void:
	_on_abilities_changed(result)
	show_toast("EVOLUȚIE: %s" % result.display_name)


func _on_boss_spawned(enemy: Enemy) -> void:
	_boss = enemy
	# Viata sefului nu vine prin semnal, deci bara se reciteste in fiecare cadru
	# cat timp el traieste. E o citire de doua numere - nu merita plumbarie.
	set_process(true)
	queue_redraw()


func show_toast(text: String) -> void:
	_toast = text
	_toast_left = TOAST_TIME
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
	if _boss != null and not is_instance_valid(_boss):
		_boss = null

	queue_redraw()
	if _toast_left <= 0.0 and _boss == null:
		set_process(false)


# ====================== DESEN ======================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var width := size.x - MARGIN * 2.0

	_draw_health(font, width)
	_draw_xp(font, width)
	_draw_coins(font, width)
	_draw_place(font, width)
	_draw_abilities(font)
	_draw_boss(font, width)
	if _toast_left > 0.0:
		_draw_toast(font, width)


func _draw_health(font: Font, width: float) -> void:
	var bar := Rect2(MARGIN, MARGIN, width, HEALTH_HEIGHT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55))
	var fraction := clampf(_health / _max_health, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), UiKit.DANGER)
	draw_rect(bar, Color(1, 1, 1, 0.2), false, 2.0)
	draw_string(
		font, bar.position + Vector2(10.0, 16.0),
		"%d / %d" % [roundi(_health), roundi(_max_health)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.92)
	)


func _draw_xp(font: Font, width: float) -> void:
	var top := MARGIN + HEALTH_HEIGHT + 4.0
	# Bara de experienta incepe dupa insigna de nivel, ca sa nu treaca pe sub ea.
	var badge := Rect2(MARGIN, top, 44.0, XP_HEIGHT + 12.0)
	draw_rect(badge, UiKit.PANEL_SOFT)
	draw_rect(badge, UiKit.GOLD_DIM, false, 1.5)
	draw_string(
		font, badge.position + Vector2(0.0, 15.0), "Niv. %d" % _level,
		HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 12, UiKit.GOLD
	)

	var bar := Rect2(MARGIN + badge.size.x + 8.0, top + 6.0, width - badge.size.x - 8.0, XP_HEIGHT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55))
	var fraction := clampf(_xp / _xp_needed, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), UiKit.MINT)


func _draw_coins(font: Font, width: float) -> void:
	var top := MARGIN + HEALTH_HEIGHT + XP_HEIGHT + 44.0
	draw_string(
		font, Vector2(MARGIN, top), "◆ %d" % _coins,
		HORIZONTAL_ALIGNMENT_RIGHT, width, 20, UiKit.GOLD
	)


func _draw_place(font: Font, width: float) -> void:
	var top := MARGIN + HEALTH_HEIGHT + XP_HEIGHT + 68.0
	var place := _location if not _location.is_empty() else "Heroium"
	var mode := GameState.mode_name(GameState.selected_mode)
	draw_string(
		font, Vector2(MARGIN, top), "%s · %s · camera %d" % [mode, place, _room],
		HORIZONTAL_ALIGNMENT_RIGHT, width, 14, UiKit.MUTED
	)


## Bara sefului. Sta lata, sus, si isi spune numele - o lupta care schimba regulile
## la jumatate merita sa arate altfel decat un schelet oarecare.
func _draw_boss(font: Font, width: float) -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.type == null:
		return

	var top := MARGIN + HEALTH_HEIGHT + XP_HEIGHT + 96.0
	var bar := Rect2(MARGIN, top, width, 18.0)
	var fraction := clampf(_boss.health / maxf(1.0, _boss.max_health), 0.0, 1.0)

	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), _boss.type.tint())
	draw_rect(bar, UiKit.GOLD_DIM, false, 2.0)

	var label := _boss.type.display_name
	if _boss.phase > 1:
		label += "  ·  FAZA A II-A"
	draw_string(
		font, Vector2(MARGIN, top - 5.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, width, 15, UiKit.GOLD
	)


## Abilitatile stranse, ca puncte colorate dupa raritate. Nu sunt iconite, dar
## spun lucrul care conteaza in lupta: cate ai si cat de bune sunt.
func _draw_abilities(font: Font) -> void:
	if _abilities.is_empty():
		return

	var dot := 30.0
	var gap := 8.0
	var origin := Vector2(size.x - MARGIN - dot, size.y - MARGIN - dot)

	for i in _abilities.size():
		var ability := _abilities[i]
		var center := origin - Vector2(0.0, float(i) * (dot + gap)) + Vector2(dot, dot) * 0.5
		var color := UiKit.rarity_color(ability.rarity)
		draw_circle(center, dot * 0.5, Color(color.r, color.g, color.b, 0.22))
		draw_arc(center, dot * 0.5, 0.0, TAU, 24, color, 2.0, true)
		draw_string(
			font, center + Vector2(-dot * 0.5, 5.0), str(ability.stars),
			HORIZONTAL_ALIGNMENT_CENTER, dot, 14, color
		)


func _draw_toast(font: Font, width: float) -> void:
	# Se stinge pe ultima jumatate de secunda, ca sa nu dispara taiat.
	var alpha := clampf(_toast_left / 0.5, 0.0, 1.0)
	var color := UiKit.GOLD
	color.a = alpha
	draw_string(
		font, Vector2(MARGIN, size.y * 0.28), _toast,
		HORIZONTAL_ALIGNMENT_CENTER, width, 28, color
	)
