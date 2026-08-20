extends Control

## Alegerea de la ridicarea unui nivel: trei carti, iei una.
##
## E momentul in care se decide cum arata rularea. Doua lucruri conteaza aici si
## sunt tratate anume:
##
## 1. Un singur ciob de experienta poate ridica doua niveluri odata. Alegerile nu
##    se pierd si nu se suprapun - se aseaza la coada si vin una dupa alta.
## 2. Daca o carte fuzioneaza cu ceva ce ai deja, cartea o spune. Altfel evolutia
##    ar fi un accident fericit pe care jucatorul nu l-ar putea urmari niciodata.

## Cate carti se ofera de fiecare data.
const CARD_COUNT := 3

@export var hero_path: NodePath
@export var arena_path: NodePath

var _hero: Hero = null
var _arena: Arena = null
var _pending: int = 0
var _rows: VBoxContainer = null
var _title: Label = null


func _ready() -> void:
	# Ecranul opreste jocul, deci trebuie sa fie el insusi in afara opririi.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_build()

	_arena = get_node_or_null(arena_path) as Arena
	_hero = get_node_or_null(hero_path) as Hero
	if _hero != null:
		_hero.leveled_up.connect(_on_leveled_up)


func _build() -> void:
	add_child(UiKit.dim_overlay())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	_title = UiKit.title("NIVEL 2")
	column.add_child(_title)

	var hint := UiKit.body("Alege o carte", 15)
	column.add_child(hint)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	column.add_child(_rows)


func _on_leveled_up(_level: int) -> void:
	_pending += 1
	if not visible:
		_present()


func _present() -> void:
	if _hero == null or (_arena != null and _arena.is_over):
		_pending = 0
		return

	var picks := _draw_hand()
	if picks.is_empty():
		# Nimic de oferit (tot pachetul e inca blocat): nu bloca jocul cu un
		# ecran gol.
		_pending = 0
		return

	_title.text = "NIVEL %d" % _hero.get_level()

	for child in _rows.get_children():
		child.queue_free()
	for ability in picks:
		_rows.add_child(_make_card(ability))

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true


## Trage CARD_COUNT abilitati diferite din cele deblocate.
func _draw_hand() -> Array[Ability]:
	var pool := GameState.draftable_abilities()
	pool.shuffle()

	var hand: Array[Ability] = []
	for ability in pool:
		if hand.size() >= CARD_COUNT:
			break
		hand.append(ability)
	return hand


## Cu ce abilitate detinuta ar fuziona cartea asta, daca ar fuziona cu vreuna.
func _fusion_partner(ability: Ability) -> Ability:
	for owned in _hero.get_abilities():
		if owned.can_fuse_with(ability) or ability.can_fuse_with(owned):
			return owned
	return null


func _make_card(ability: Ability) -> Button:
	var color := UiKit.rarity_color(ability.rarity)
	var partner := _fusion_partner(ability)

	var card := Button.new()
	card.custom_minimum_size.y = 104.0
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL, color))
	card.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, color, 14.0, 3))
	card.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.INK, color, 14.0, 3))
	card.pressed.connect(_on_card_picked.bind(ability))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	rows.add_child(_line("%s   %s" % [ability.display_name, UiKit.stars(ability.stars)], 19, color))
	rows.add_child(_line(ability.description, 14, UiKit.MUTED, true))
	if partner != null:
		rows.add_child(_line("⚡ EVOLUEAZĂ cu %s" % partner.display_name, 13, UiKit.GOLD))

	return card


func _line(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _on_card_picked(ability: Ability) -> void:
	_hero.grant_ability(ability)
	_pending = maxi(0, _pending - 1)

	if _pending > 0:
		# Inca un nivel asteapta: ramane pe ecran, dar cu o mana noua.
		_present()
		return

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Daca eroul a murit intre timp, oprirea nu ne apartine - o lasam asa.
	if _arena == null or not _arena.is_over:
		get_tree().paused = false
