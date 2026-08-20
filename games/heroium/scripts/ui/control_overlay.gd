extends Control

## UI compact pentru alegerea stilului de control si pentru atacurile manuale.
## Nu decide combat-ul; doar trimite comenzi catre Hero.

@export var hero_path: NodePath
@export var attack_joystick_path: NodePath

var _hero: Hero
var _attack_button: Button
var _mode_button: Button
var _info_label: Label
var _attack_joystick: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hero = get_node_or_null(hero_path) as Hero
	_attack_joystick = get_node_or_null(attack_joystick_path) as Control

	_build_mode_button()
	_build_attack_button()
	_build_info()
	_refresh()

	if _hero != null:
		_hero.control_mode_changed.connect(_on_mode_changed)
		_hero.died.connect(_on_hero_died)

func _build_mode_button() -> void:
	_mode_button = Button.new()
	_mode_button.name = "ControlModeButton"
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_button.position = Vector2(-190.0, 20.0)
	_mode_button.size = Vector2(170.0, 58.0)
	_mode_button.add_theme_font_size_override("font_size", 13)
	_mode_button.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD_DIM, 12.0))
	_mode_button.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD, 12.0))
	_mode_button.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.PANEL, UiKit.GOLD, 12.0))
	_mode_button.add_theme_color_override("font_color", UiKit.GOLD)
	_mode_button.pressed.connect(_cycle_mode)
	add_child(_mode_button)

func _build_attack_button() -> void:
	_attack_button = Button.new()
	_attack_button.name = "AttackButton"
	_attack_button.focus_mode = Control.FOCUS_NONE
	_attack_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_attack_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_attack_button.position = Vector2(-170.0, -190.0)
	_attack_button.size = Vector2(120.0, 120.0)
	_attack_button.text = "ATAC"
	_attack_button.add_theme_font_size_override("font_size", 18)
	_attack_button.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD_DIM, 60.0))
	_attack_button.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD, 60.0))
	_attack_button.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.PANEL, UiKit.GOLD, 60.0))
	_attack_button.add_theme_color_override("font_color", UiKit.GOLD)
	_attack_button.button_down.connect(_attack_down)
	_attack_button.button_up.connect(_attack_up)
	_attack_button.pressed.connect(_attack_pressed)
	add_child(_attack_button)

func _build_info() -> void:
	_info_label = Label.new()
	_info_label.name = "ControlInfo"
	_info_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info_label.position = Vector2(0.0, -78.0)
	_info_label.size = Vector2(0.0, 48.0)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	add_child(_info_label)

func _cycle_mode() -> void:
	if _hero == null:
		return
	_hero.cycle_control_mode()
	Fx.toast("CONTROL: %s" % _hero.get_control_mode_name())

func _attack_down() -> void:
	if _hero != null and _hero.control_mode == HeroControl.Mode.HOLD_TO_FIRE:
		_hero.set_attack_button_down(true)

func _attack_up() -> void:
	if _hero != null:
		_hero.set_attack_button_down(false)

func _attack_pressed() -> void:
	if _hero != null and _hero.control_mode == HeroControl.Mode.TAP_TO_FIRE:
		_hero.tap_attack()

func _on_mode_changed(_mode: HeroControl.Mode) -> void:
	_refresh()

func _on_hero_died() -> void:
	_attack_button.hide()
	_mode_button.hide()

func _refresh() -> void:
	if _hero == null:
		return

	_mode_button.text = "CONTROL\n%s" % _hero.get_control_mode_name()
	_info_label.text = "%s  •  Inamici: %d%%" % [
		_hero.get_control_description(),
		roundi(_hero.get_enemy_difficulty_multiplier() * 100.0),
	]

	var manual_button := _hero.control_mode == HeroControl.Mode.TAP_TO_FIRE or _hero.control_mode == HeroControl.Mode.HOLD_TO_FIRE
	_attack_button.visible = manual_button

	if _attack_joystick != null:
		_attack_joystick.visible = _hero.control_mode == HeroControl.Mode.DUAL_STICK
