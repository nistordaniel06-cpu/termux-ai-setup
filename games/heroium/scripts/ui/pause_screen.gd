extends Control

## Pauza. Se deschide din butonul HUD-ului si arata ce ai strans pana acum.
##
## Nu se deschide daca rularea s-a incheiat deja: acolo comanda ecranul de final,
## si doua ecrane peste acelasi joc oprit ar sta unul peste altul.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@export var hud_path: NodePath
@export var hero_path: NodePath
@export var arena_path: NodePath

var _hero: Hero = null
var _arena: Arena = null
var _stats: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_build()

	_hero = get_node_or_null(hero_path) as Hero
	_arena = get_node_or_null(arena_path) as Arena

	var hud := get_node_or_null(hud_path)
	if hud != null:
		hud.pause_pressed.connect(open)


func _build() -> void:
	add_child(UiKit.dim_overlay())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	column.add_child(UiKit.title("PAUZĂ"))

	_stats = UiKit.body("", 16, UiKit.TEXT)
	column.add_child(_stats)

	var resume := UiKit.button("CONTINUĂ", true)
	resume.pressed.connect(close)
	column.add_child(resume)

	var quit := UiKit.button("RENUNȚĂ LA RULARE")
	quit.pressed.connect(_on_quit)
	column.add_child(quit)


func open() -> void:
	if _arena != null and _arena.is_over:
		return

	var abilities := 0
	if _hero != null:
		abilities = _hero.get_abilities().size()

	_stats.text = "Nivel %d · %d abilități\n%d camere în rularea asta" % [
		_hero.get_level() if _hero != null else 1,
		abilities,
		_arena.rooms_cleared if _arena != null else 0,
	]

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
