extends Control

## Ce vezi cand cazi: cat ai apucat sa faci si cele doua drumuri de acolo.
##
## Rularea s-a pierdut, dar monedele stranse in ea nu - ele sunt deja in
## GameState si te asteapta in Tabara. Ecranul o spune pe fata, fiindca asta e
## intelegerea genului: pierzi rularea, nu progresul.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@export var arena_path: NodePath

var _title: Label = null
var _summary: Label = null
var _record: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_build()

	var arena := get_node_or_null(arena_path) as Arena
	if arena != null:
		arena.run_ended.connect(_on_run_ended)
		arena.run_won.connect(_on_run_won)


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

	_title = UiKit.title(Loc.t("game_over"), 38, UiKit.DANGER)
	column.add_child(_title)

	_summary = UiKit.body("", 18, UiKit.TEXT)
	column.add_child(_summary)

	_record = UiKit.body("", 14)
	column.add_child(_record)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	column.add_child(spacer)

	var again := UiKit.button(Loc.t("btn_retry"), true)
	again.pressed.connect(_on_retry)
	column.add_child(again)

	var camp := UiKit.button(Loc.t("tab_camp"))
	camp.pressed.connect(_on_menu)
	column.add_child(camp)


func _on_run_ended(rooms_cleared: int, coins_earned: int) -> void:
	_title.text = Loc.t("game_over")
	_title.add_theme_color_override("font_color", UiKit.DANGER)

	if rooms_cleared >= GameState.best_run_rooms and rooms_cleared > 0:
		_record.text = "Cel mai bun rezultat al tău."
	else:
		_record.text = "Recordul tău: %d camere.\nMonedele rămân — cumpără talente în Tabără." \
			% GameState.best_run_rooms

	_show(rooms_cleared, coins_earned)


## Campania dusa pana la capat. Merita alt cuvant si alta culoare decat o cadere -
## altfel singurul final pe care il poate atinge jucatorul arata a esec.
func _on_run_won(rooms_cleared: int, coins_earned: int) -> void:
	_title.text = Loc.t("victory")
	_title.add_theme_color_override("font_color", UiKit.GOLD)
	_record.text = "Ai trecut toate cele patru tărâmuri.\nÎncearcă Supraviețuire, sau alt erou."
	_show(rooms_cleared, coins_earned)


func _show(rooms_cleared: int, coins_earned: int) -> void:
	_summary.text = "%d camere curățate\n%d monede strânse" % [rooms_cleared, coins_earned]
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
