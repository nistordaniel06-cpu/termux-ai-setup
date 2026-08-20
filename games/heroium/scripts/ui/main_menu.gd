extends Control

## Ecranul dintre rulari: erou, mod, tabara.
## Reactioneaza la Loc.language_changed - toate textele se refac la toggle.

const GAME_SCENE := "res://scenes/main.tscn"

enum Page { HEROES, MODES, CAMP }

var _page: Page = Page.HEROES
var _content: VBoxContainer = null
var _coins_label: Label = null
var _tab_btns: Array[Button] = []
var _lang_btn: Button = null
var _title_label: Label = null
var _tagline_label: Label = null
var _play_btn: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.coins_changed.connect(func(_v: int) -> void: _refresh_text())
	Loc.language_changed.connect(_refresh_text)
	_refresh()


func _build() -> void:
	# Fundal gradient subtil
	var bg := _gradient_bg()
	add_child(bg)

	# Marginile principale
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# --- Header ---
	var header := _build_header()
	column.add_child(header)

	# --- Tabs ---
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	column.add_child(tabs_row)

	_tab_btns.clear()
	for i in [Page.HEROES, Page.MODES, Page.CAMP]:
		var btn := _tab_button(i)
		tabs_row.add_child(btn)
		_tab_btns.append(btn)

	# --- Scroll ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	# --- Play ---
	_play_btn = _make_play_btn()
	column.add_child(_play_btn)


func _build_header() -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)

	# Rând: titlu + buton limbă
	var top_row := HBoxContainer.new()
	stack.add_child(top_row)

	# Spacer stânga
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_l)

	_title_label = Label.new()
	_title_label.text = "HEROIUM"
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", UiKit.GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(_title_label)

	# Spacer dreapta + buton limbă
	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_r)

	_lang_btn = Button.new()
	_lang_btn.text = Loc.lang_label()
	_lang_btn.custom_minimum_size = Vector2(48, 36)
	_lang_btn.focus_mode = Control.FOCUS_NONE
	_lang_btn.add_theme_font_size_override("font_size", 13)
	_lang_btn.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD_DIM, 8.0))
	_lang_btn.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.PANEL_SOFT, UiKit.GOLD, 8.0))
	_lang_btn.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.INK, UiKit.GOLD, 8.0))
	_lang_btn.add_theme_color_override("font_color", UiKit.GOLD)
	_lang_btn.add_theme_color_override("font_hover_color", UiKit.GOLD)
	_lang_btn.add_theme_color_override("font_pressed_color", UiKit.GOLD)
	_lang_btn.pressed.connect(_on_lang_toggle)
	top_row.add_child(_lang_btn)

	_tagline_label = Label.new()
	_tagline_label.text = Loc.t("tagline")
	_tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline_label.add_theme_font_size_override("font_size", 13)
	_tagline_label.add_theme_color_override("font_color", UiKit.MUTED)
	_tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_tagline_label)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 17)
	_coins_label.add_theme_color_override("font_color", UiKit.GOLD)
	stack.add_child(_coins_label)

	return stack


func _tab_button(page: Page) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 44
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_show_page.bind(page))
	return btn


func _make_play_btn() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size.y = 62
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_stylebox_override("normal", UiKit.outlined(UiKit.GOLD, UiKit.GOLD.lightened(0.2), 14.0))
	btn.add_theme_stylebox_override("hover", UiKit.outlined(UiKit.GOLD.lightened(0.1), UiKit.GOLD.lightened(0.3), 14.0))
	btn.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.GOLD.darkened(0.2), UiKit.GOLD, 14.0))
	btn.add_theme_color_override("font_color", UiKit.INK)
	btn.add_theme_color_override("font_hover_color", UiKit.INK)
	btn.add_theme_color_override("font_pressed_color", UiKit.INK)
	btn.pressed.connect(_on_play)
	return btn


func _gradient_bg() -> Control:
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg


# ====================== NAVIGARE ======================

func _show_page(page: Page) -> void:
	_page = page
	_refresh()


func _refresh() -> void:
	_refresh_text()
	_rebuild_content()


func _refresh_text() -> void:
	_coins_label.text = "◆  %d %s" % [GameState.coins, Loc.t("coins")]
	_tagline_label.text = Loc.t("tagline")
	_play_btn.text = Loc.t("btn_play")
	_lang_btn.text = Loc.lang_label()

	var labels := [Loc.t("tab_heroes"), Loc.t("tab_modes"), Loc.t("tab_camp")]
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		var active := _page == i
		btn.text = labels[i]
		var bg := UiKit.GOLD if active else UiKit.PANEL_SOFT
		var border := UiKit.GOLD if active else UiKit.GOLD_DIM
		var fc := UiKit.INK if active else UiKit.TEXT
		btn.add_theme_stylebox_override("normal", UiKit.outlined(bg, border, 10.0))
		btn.add_theme_stylebox_override("hover", UiKit.outlined(bg.lightened(0.06), UiKit.GOLD, 10.0))
		btn.add_theme_stylebox_override("pressed", UiKit.outlined(bg.darkened(0.1), UiKit.GOLD, 10.0))
		btn.add_theme_color_override("font_color", fc)
		btn.add_theme_color_override("font_hover_color", fc)
		btn.add_theme_color_override("font_pressed_color", fc)


func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	match _page:
		Page.HEROES: _build_heroes()
		Page.MODES:  _build_modes()
		_:           _build_camp()


# ====================== EROI ======================

func _build_heroes() -> void:
	for hero in GameState.heroes:
		_content.add_child(_hero_card(hero))

	_content.add_child(_section_divider(Loc.t("appearance_title"), Loc.t("appearance_sub")))

	for skin in GameState.skins:
		_content.add_child(_skin_card(skin))


func _hero_card(hero: HeroClass) -> Control:
	var unlocked := GameState.is_hero_unlocked(hero.id)
	var chosen := GameState.selected_hero_class()
	var is_selected := unlocked and chosen != null and chosen.id == hero.id
	var accent := hero.accent_color if unlocked else UiKit.MUTED

	var row := _card_button(is_selected, accent, 112.0)
	row.pressed.connect(_on_hero_pressed.bind(hero))

	var inner := _card_inner(row)

	# Bara colorată stânga
	var bar := _accent_bar(accent)
	inner.add_child(bar)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_row)

	name_row.add_child(_label(hero.display_name, 19, accent if unlocked else UiKit.MUTED))

	if is_selected:
		name_row.add_child(_pill("✓ " + Loc.t("btn_selected"), UiKit.GOLD.darkened(0.3), UiKit.GOLD))
	elif not unlocked:
		name_row.add_child(_pill("🔒 %d" % hero.unlock_cost, UiKit.PANEL_SOFT, UiKit.MUTED))

	if hero.stats != null:
		var stats_str := "ATK %d  ·  HP %d  ·  DEF %d  ·  %.1f/s" % [
			roundi(hero.stats.base_attack),
			roundi(hero.stats.base_health),
			roundi(hero.stats.base_defense),
			hero.stats.base_attack_speed,
		]
		texts.add_child(_label(stats_str, 12, UiKit.TEXT))

	var desc := _label(hero.description, 12, UiKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)

	return row


func _skin_card(skin: HeroSkin) -> Control:
	var unlocked := GameState.is_skin_unlocked(skin.id)
	var worn := GameState.selected_skin_resource()
	var is_worn := unlocked and worn != null and worn.id == skin.id
	var accent := skin.color if unlocked else UiKit.MUTED

	var row := _card_button(is_worn, accent, 76.0)
	row.pressed.connect(_on_skin_pressed.bind(skin))

	var inner := _card_inner(row)

	var bar := _accent_bar(accent)
	inner.add_child(bar)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_row)

	name_row.add_child(_label(skin.display_name, 17, accent if unlocked else UiKit.MUTED))

	if is_worn:
		name_row.add_child(_pill("✓ " + Loc.t("btn_worn"), skin.color.darkened(0.4), skin.color))
	elif not unlocked:
		name_row.add_child(_pill("🔒 %d" % skin.cost, UiKit.PANEL_SOFT, UiKit.MUTED))

	var desc := _label(skin.description, 12, UiKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)

	return row


func _on_hero_pressed(hero: HeroClass) -> void:
	if GameState.is_hero_unlocked(hero.id):
		GameState.select_hero(hero.id)
	else:
		GameState.unlock_hero(hero.id, hero.unlock_cost)
		if GameState.is_hero_unlocked(hero.id):
			GameState.select_hero(hero.id)
	_refresh()


func _on_skin_pressed(skin: HeroSkin) -> void:
	if GameState.is_skin_unlocked(skin.id):
		GameState.select_skin(skin.id)
	else:
		GameState.unlock_skin(skin.id, skin.cost)
		if GameState.is_skin_unlocked(skin.id):
			GameState.select_skin(skin.id)
	_refresh()


# ====================== MODURI ======================

func _build_modes() -> void:
	_content.add_child(_body_label(Loc.t("modes_intro")))

	var mode_keys := [
		[GameState.Mode.CAMPAIGN, "mode_campaign", "mode_campaign_about"],
		[GameState.Mode.SURVIVAL, "mode_survival", "mode_survival_about"],
		[GameState.Mode.BOSS_RUSH, "mode_bossrush", "mode_bossrush_about"],
	]

	for entry in mode_keys:
		_content.add_child(_mode_card(entry[0], entry[1], entry[2]))


func _mode_card(mode: int, name_key: String, about_key: String) -> Control:
	var chosen := GameState.selected_mode == mode
	var accent := UiKit.GOLD if chosen else UiKit.GOLD_DIM

	var row := _card_button(chosen, accent, 90.0)
	row.pressed.connect(_on_mode_pressed.bind(mode))

	var inner := _card_inner(row)
	inner.add_child(_accent_bar(accent))

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_row)
	name_row.add_child(_label(Loc.t(name_key), 19, UiKit.GOLD if chosen else UiKit.TEXT))
	if chosen:
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(sp)
		name_row.add_child(_pill("✓", UiKit.GOLD.darkened(0.4), UiKit.GOLD))

	var desc := _label(Loc.t(about_key), 12, UiKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)

	return row


func _on_mode_pressed(mode: int) -> void:
	GameState.select_mode(mode)
	_refresh()


# ====================== TABARA ======================

func _build_camp() -> void:
	_content.add_child(_body_label(Loc.t("camp_intro")))

	for id: StringName in GameState.TALENTS:
		_content.add_child(_talent_card(id))


func _talent_card(id: StringName) -> Control:
	var data: Dictionary = GameState.TALENTS[id]
	var level := GameState.talent_level(id)
	var maximum: int = data["max"]
	var available := GameState.is_talent_available(id)
	var maxed := level >= maximum
	var affordable := GameState.can_buy_talent(id)
	var name_key := "talent_" + str(id)
	var display_name: String = Loc.t(name_key) if _STRINGS_HAS(name_key) else data["name"]
	var accent := UiKit.GOLD if affordable else (UiKit.MINT if maxed else UiKit.MUTED)

	var row := _card_button(false, accent, 82.0)
	row.disabled = not affordable
	row.pressed.connect(_on_talent_pressed.bind(id))

	var inner := _card_inner(row)
	inner.add_child(_accent_bar(accent))

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)

	# Rând: nume + nivel
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_row)
	name_row.add_child(_label(display_name, 17, accent))

	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(sp)

	# Bara de nivel
	name_row.add_child(_level_bar(level, maximum))

	var note := ""
	if not available:
		var requires: StringName = data["requires"]
		var req_key := "talent_" + str(requires)
		var req_name: String = Loc.t(req_key) if _STRINGS_HAS(req_key) else GameState.TALENTS[requires]["name"]
		note = Loc.t("requires_first") + req_name
	elif maxed:
		note = Loc.t("at_max")
	else:
		note = "%d %s" % [GameState.talent_cost(id), Loc.t("coins")]

	texts.add_child(_label(note, 12, UiKit.MUTED if not affordable else UiKit.TEXT))

	return row


func _STRINGS_HAS(key: String) -> bool:
	return Loc._STRINGS.has(key)


func _on_talent_pressed(id: StringName) -> void:
	if GameState.buy_talent(id):
		_refresh()


func _on_lang_toggle() -> void:
	Loc.toggle()


# ====================== HELPERS VIZUALE ======================

func _card_button(active: bool, accent: Color, min_h: float) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size.y = min_h
	btn.focus_mode = Control.FOCUS_NONE
	var bg := UiKit.PANEL_SOFT if active else UiKit.PANEL
	var border := accent
	btn.add_theme_stylebox_override("normal", UiKit.outlined(bg, border, 12.0, 2 if active else 1))
	btn.add_theme_stylebox_override("hover", UiKit.outlined(bg.lightened(0.06), accent.lightened(0.1), 12.0, 2))
	btn.add_theme_stylebox_override("pressed", UiKit.outlined(UiKit.INK, accent, 12.0, 2))
	btn.add_theme_stylebox_override("disabled", UiKit.outlined(UiKit.PANEL, UiKit.GOLD_DIM.darkened(0.5), 12.0))
	return btn


func _card_inner(parent: Control) -> HBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	parent.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	return row


func _accent_bar(color: Color) -> Control:
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _pill(text: String, bg: Color, fg: Color) -> Label:
	var lbl := Label.new()
	lbl.text = "  %s  " % text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", fg)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fara StyleBox real - nu avem PanelContainer usor de stilizat dinamic,
	# asa ca folosim fundalul labelului prin culoare de font contrastanta.
	return lbl


func _level_bar(level: int, max_level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in max_level:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 8)
		pip.color = UiKit.GOLD if i < level else UiKit.PANEL_SOFT
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return row


func _section_divider(title: String, subtitle: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", UiKit.GOLD_DIM)
	box.add_child(sep)

	box.add_child(_label(title, 16, UiKit.GOLD, true))
	box.add_child(_label(subtitle, 11, UiKit.MUTED, true))
	return box


func _body_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UiKit.MUTED)
	return lbl


func _label(text: String, size: int, color: Color, centered: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
