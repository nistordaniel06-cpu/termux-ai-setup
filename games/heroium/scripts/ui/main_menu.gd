extends Control

## Ecranul dintre rulari: de unde pornesti, cu cine pornesti si pe ce cheltui
## ce-ai adunat.
##
## Doua pagini, fiindca sunt doua intrebari diferite: EROI ("cu cine intru")
## si TABĂRA ("ce-mi cumpar din ce-am scos"). Amandoua sunt reconstruite din
## GameState de fiecare data cand se schimba ceva - nu exista o a doua copie a
## adevarului care s-ar putea desincroniza.

const GAME_SCENE := "res://scenes/main.tscn"

enum Page { HEROES, CAMP }

var _page: Page = Page.HEROES
var _content: VBoxContainer = null
var _coins_label: Label = null
var _heroes_tab: Button = null
var _camp_tab: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.coins_changed.connect(func(_amount: int) -> void: _refresh())
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = UiKit.INK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(UiKit.title("HEROIUM", 44))
	column.add_child(UiKit.body("Luptă. Adună. Evoluează. Devino legendar.", 14))

	_coins_label = UiKit.title("", 20)
	column.add_child(_coins_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)

	_heroes_tab = UiKit.button("EROI", false, 48)
	_heroes_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heroes_tab.pressed.connect(_show_page.bind(Page.HEROES))
	tabs.add_child(_heroes_tab)

	_camp_tab = UiKit.button("TABĂRA", false, 48)
	_camp_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_tab.pressed.connect(_show_page.bind(Page.CAMP))
	tabs.add_child(_camp_tab)

	# Pagina poate fi mai inalta decat ecranul (cinci talente, trei eroi), deci
	# trebuie sa se poata trage cu degetul.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	var play := UiKit.button("PORNEȘTE", true, 68)
	play.pressed.connect(_on_play)
	column.add_child(play)


func _show_page(page: Page) -> void:
	_page = page
	_refresh()


func _refresh() -> void:
	_coins_label.text = "◆ %d monede" % GameState.coins
	_heroes_tab.disabled = _page == Page.HEROES
	_camp_tab.disabled = _page == Page.CAMP

	for child in _content.get_children():
		child.queue_free()

	if _page == Page.HEROES:
		_build_heroes()
	else:
		_build_camp()


# ====================== EROI ======================

func _build_heroes() -> void:
	for hero in GameState.heroes:
		_content.add_child(_hero_row(hero))


func _hero_row(hero: HeroClass) -> Control:
	var unlocked := GameState.is_hero_unlocked(hero.id)
	var chosen := GameState.selected_hero_class()
	var is_selected := unlocked and chosen != null and chosen.id == hero.id

	var border := hero.accent_color if is_selected else UiKit.GOLD_DIM
	var row := Button.new()
	row.custom_minimum_size.y = 116.0
	row.focus_mode = Control.FOCUS_NONE
	row.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL, border))
	row.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, border, 14.0, 3))
	row.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.INK, border, 14.0, 3))
	row.pressed.connect(_on_hero_pressed.bind(hero))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	row.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)

	var heading := hero.display_name
	if is_selected:
		heading += "   ✓ ales"
	elif not unlocked:
		heading += "   🔒 %d monede" % hero.unlock_cost
	rows.add_child(_line(heading, 20, hero.accent_color if unlocked else UiKit.MUTED))

	if hero.stats != null:
		rows.add_child(_line(
			"ATK %d   ·   HP %d   ·   DEF %d   ·   %.1f atac/s" % [
				roundi(hero.stats.base_attack),
				roundi(hero.stats.base_health),
				roundi(hero.stats.base_defense),
				hero.stats.base_attack_speed,
			], 13, UiKit.TEXT))
	rows.add_child(_line(hero.description, 12, UiKit.MUTED, true))

	return row


func _on_hero_pressed(hero: HeroClass) -> void:
	if GameState.is_hero_unlocked(hero.id):
		GameState.select_hero(hero.id)
	else:
		GameState.unlock_hero(hero.id, hero.unlock_cost)
		# Deblocat chiar acum? Atunci e si ales - altfel ar trebui apasat de doua ori.
		if GameState.is_hero_unlocked(hero.id):
			GameState.select_hero(hero.id)
	_refresh()


# ====================== TABĂRA (CALEA LEGENDARĂ) ======================

func _build_camp() -> void:
	_content.add_child(UiKit.body(
		"Talentele rămân pentru totdeauna. Rularea se pierde, ele nu.", 13))

	for id: StringName in GameState.TALENTS:
		_content.add_child(_talent_row(id))


func _talent_row(id: StringName) -> Control:
	var data: Dictionary = GameState.TALENTS[id]
	var level := GameState.talent_level(id)
	var maximum: int = data["max"]
	var available := GameState.is_talent_available(id)
	var maxed := level >= maximum
	var affordable := GameState.can_buy_talent(id)

	var row := Button.new()
	row.custom_minimum_size.y = 84.0
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not affordable

	var border := UiKit.GOLD if affordable else UiKit.GOLD_DIM
	row.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL, border))
	row.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, border, 14.0, 3))
	row.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.INK, border, 14.0, 3))
	row.add_theme_stylebox_override("disabled", UiKit.outlined(UiKit.PANEL, UiKit.GOLD_DIM.darkened(0.45)))
	row.pressed.connect(_on_talent_pressed.bind(id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)

	var name_color := UiKit.GOLD if available else UiKit.MUTED
	rows.add_child(_line("%s   %d/%d" % [data["name"], level, maximum], 18, name_color))

	var note := ""
	if not available:
		var requires: StringName = data["requires"]
		note = "Cere mai întâi %s." % GameState.TALENTS[requires]["name"]
	elif maxed:
		note = "La maxim."
	else:
		note = "%d monede" % GameState.talent_cost(id)
	rows.add_child(_line(note, 13, UiKit.TEXT if affordable else UiKit.MUTED))

	return row


func _on_talent_pressed(id: StringName) -> void:
	if GameState.buy_talent(id):
		_refresh()


# ====================== UNELTE ======================

func _line(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
