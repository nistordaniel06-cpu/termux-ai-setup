class_name UiKit

## Stilurile comune ale interfetei, facute in cod.
##
## Nu exista fisier de tema si nici fonturi importate: pe toate ecranele se
## folosesc aceleasi cateva functii de aici, deci nu se pot desincroniza intre
## ele. Cand va exista o tema adevarata, se inlocuieste fisierul asta si nimic
## altceva.

const GOLD := Color("f0b45a")
const GOLD_DIM := Color("8a6a34")
const INK := Color("0b0910")
const PANEL := Color("171325")
const PANEL_SOFT := Color("221c33")
const TEXT := Color("e8e3f0")
const MUTED := Color("9a92ad")
const DANGER := Color("e2574c")
const MINT := Color("5ef0b6")

## Culorile raritatilor, in ordinea din Ability.Rarity.
const RARITY_COLORS: Array[Color] = [
	Color("9a92ad"),  # comuna
	Color("5aa9f0"),  # rara
	Color("c86bf0"),  # epica
	Color("f0b45a"),  # legendara
	Color("e2665a"),  # mythic
]


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


## Sirul de stele al unei abilitati, asa cum apare pe carti.
static func stars(count: int) -> String:
	return "★".repeat(clampi(count, 0, 5))


static func fill(color: Color, radius: float = 14.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	return box


static func outlined(color: Color, border: Color, radius: float = 14.0, width: int = 2) -> StyleBoxFlat:
	var box := fill(color, radius)
	box.border_color = border
	box.set_border_width_all(width)
	return box


static func title(text: String, size: int = 34, color: Color = GOLD) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func body(text: String, size: int = 16, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Butonul obisnuit: auriu plin pentru actiunea principala, contur pentru rest.
static func button(text: String, primary: bool = false, height: float = 62.0) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = height
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size", 20)

	var base := GOLD if primary else PANEL_SOFT
	var text_color := INK if primary else TEXT

	control.add_theme_stylebox_override("normal", outlined(base, GOLD_DIM))
	control.add_theme_stylebox_override("hover", outlined(base.lightened(0.08), GOLD))
	control.add_theme_stylebox_override("pressed", outlined(base.darkened(0.18), GOLD))
	control.add_theme_stylebox_override("disabled", outlined(PANEL, GOLD_DIM.darkened(0.4)))
	control.add_theme_color_override("font_color", text_color)
	control.add_theme_color_override("font_hover_color", text_color)
	control.add_theme_color_override("font_pressed_color", text_color)
	control.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	return control


## Fundalul intunecat peste care se aseaza ecranele care opresc jocul.
static func dim_overlay() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.02, 0.02, 0.04, 0.82)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect
