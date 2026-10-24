class_name EditorTheme
extends RefCounted
## Dark studio theme shared by every editor panel. Keeps the UI visually
## separate from the light editorial composition.

const BG := Color("#111419")
const PANEL := Color("#191E25")
const PANEL_2 := Color("#20262F")
const PANEL_3 := Color("#28303A")
const LINE := Color("#303A46")
const TEXT := Color("#E8EDF3")
const MUTED := Color("#8B98A8")
const ACCENT := Color("#FF6A45")
const ACCENT_DIM := Color("#5C2B22")
const BLUE := Color("#62AEDA")
const GREEN := Color("#72CE9B")
const RED := Color("#FF6464")
const YELLOW := Color("#E9C46A")


static func flat(color: Color, radius: float = 4.0, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func padded(color: Color, radius: float = 4.0, h: float = 8.0, v: float = 5.0, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var sb := flat(color, radius, border, border_w)
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13

	# Panels ------------------------------------------------------------
	t.set_stylebox("panel", "PanelContainer", flat(PANEL))
	t.set_stylebox("panel", "Panel", flat(PANEL))
	t.set_stylebox("panel", "ScrollContainer", flat(Color.TRANSPARENT))
	t.set_stylebox("panel", "TabContainer", flat(PANEL))
	t.set_stylebox("tab_selected", "TabContainer", padded(PANEL_2, 0, 14, 7))
	t.set_stylebox("tab_unselected", "TabContainer", padded(PANEL, 0, 14, 7))
	t.set_stylebox("tab_hovered", "TabContainer", padded(PANEL_3, 0, 14, 7))
	t.set_color("font_selected_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_constant("side_margin", "TabContainer", 0)

	# Labels ------------------------------------------------------------
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "RichTextLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 13)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_stylebox("normal", "RichTextLabel", flat(Color.TRANSPARENT))

	# Buttons -----------------------------------------------------------
	t.set_stylebox("normal", "Button", padded(PANEL_2, 4, 9, 5, LINE, 1))
	t.set_stylebox("hover", "Button", padded(PANEL_3, 4, 9, 5, Color("#45515F"), 1))
	t.set_stylebox("pressed", "Button", padded(ACCENT_DIM, 4, 9, 5, ACCENT, 1))
	t.set_stylebox("disabled", "Button", padded(Color("#181C22"), 4, 9, 5, Color("#252C35"), 1))
	t.set_stylebox("focus", "Button", padded(Color.TRANSPARENT, 4, 9, 5, Color(ACCENT, 0.65), 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#5C6674"))
	t.set_font_size("font_size", "Button", 13)
	t.set_constant("h_separation", "Button", 5)

	# Text input --------------------------------------------------------
	for cls in ["LineEdit", "TextEdit", "CodeEdit"]:
		t.set_stylebox("normal", cls, padded(Color("#141920"), 3, 8, 5, LINE, 1))
		t.set_stylebox("focus", cls, padded(Color("#141920"), 3, 8, 5, ACCENT, 1))
		t.set_stylebox("read_only", cls, padded(Color("#171B21"), 3, 8, 5, Color("#252C35"), 1))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_placeholder_color", cls, Color("#66717F"))
		t.set_color("caret_color", cls, ACCENT)
		t.set_color("selection_color", cls, Color(ACCENT, 0.25))
		t.set_color("font_readonly_color", cls, MUTED)
		t.set_font_size("font_size", cls, 13)

	# Spin / option -----------------------------------------------------
	for cls in ["SpinBox", "OptionButton"]:
		t.set_stylebox("normal", cls, padded(Color("#141920"), 3, 7, 4, LINE, 1))
		t.set_stylebox("hover", cls, padded(Color("#181E26"), 3, 7, 4, Color("#45515F"), 1))
		t.set_stylebox("pressed", cls, padded(Color("#181E26"), 3, 7, 4, ACCENT, 1))
		t.set_stylebox("focus", cls, padded(Color("#141920"), 3, 7, 4, Color(ACCENT, 0.7), 1))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_font_size("font_size", cls, 13)
	t.set_stylebox("normal", "OptionButton", padded(Color("#141920"), 3, 8, 4, LINE, 1))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_constant("arrow_margin", "OptionButton", 8)

	# Lists / trees -----------------------------------------------------
	t.set_stylebox("panel", "ItemList", flat(Color("#141920")))
	t.set_stylebox("focus", "ItemList", flat(Color.TRANSPARENT, 0, Color(ACCENT, 0.45), 1))
	t.set_stylebox("selected", "ItemList", flat(ACCENT_DIM))
	t.set_stylebox("selected_focus", "ItemList", flat(ACCENT_DIM))
	t.set_stylebox("hovered", "ItemList", flat(PANEL_3))
	t.set_stylebox("cursor", "ItemList", flat(Color.TRANSPARENT))
	t.set_stylebox("cursor_unfocused", "ItemList", flat(Color.TRANSPARENT))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 6)
	t.set_constant("h_separation", "ItemList", 6)

	t.set_stylebox("panel", "Tree", flat(Color("#141920")))
	t.set_stylebox("focus", "Tree", flat(Color.TRANSPARENT, 0, Color(ACCENT, 0.45), 1))
	t.set_stylebox("selected", "Tree", flat(ACCENT_DIM))
	t.set_stylebox("selected_focus", "Tree", flat(ACCENT_DIM))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.04))
	t.set_constant("v_separation", "Tree", 5)
	t.set_constant("h_separation", "Tree", 5)

	# Sliders -----------------------------------------------------------
	t.set_stylebox("slider", "HSlider", flat(Color("#2A323D"), 2))
	t.set_stylebox("grabber_area", "HSlider", flat(ACCENT, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("#FF8768"), 2))
	t.set_icon("grabber", "HSlider", _circle_icon(10, Color("#E8EDF3")))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(11, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _circle_icon(10, Color("#5C6674")))

	# Scrollbars --------------------------------------------------------
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, flat(Color(0, 0, 0, 0)))
		t.set_stylebox("grabber", cls, flat(Color("#39434F"), 3))
		t.set_stylebox("grabber_highlight", cls, flat(Color("#4A5664"), 3))
		t.set_stylebox("grabber_pressed", cls, flat(ACCENT_DIM, 3))

	# Popup menus -------------------------------------------------------
	t.set_stylebox("panel", "PopupMenu", flat(PANEL_2, 5, LINE, 1))
	t.set_stylebox("hover", "PopupMenu", flat(ACCENT_DIM))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_accelerator_color", "PopupMenu", MUTED)
	t.set_font_size("font_size", "PopupMenu", 13)

	# Split containers --------------------------------------------------
	t.set_constant("separation", "HSplitContainer", 4)
	t.set_constant("separation", "VSplitContainer", 4)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "GridContainer", 8)

	# Progress / dialogs ------------------------------------------------
	t.set_stylebox("background", "ProgressBar", flat(Color("#141920"), 3, LINE, 1))
	t.set_stylebox("fill", "ProgressBar", flat(ACCENT, 3))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 12)
	t.set_stylebox("panel", "AcceptDialog", flat(PANEL))
	t.set_stylebox("panel", "Window", flat(PANEL))
	t.set_stylebox("embedded_border", "Window", flat(PANEL, 6, LINE, 1))
	t.set_color("title_color", "Window", TEXT)

	t.set_stylebox("normal", "CheckBox", flat(Color.TRANSPARENT))
	t.set_stylebox("hover", "CheckBox", flat(Color(1, 1, 1, 0.03)))
	t.set_stylebox("pressed", "CheckBox", flat(Color(1, 1, 1, 0.05)))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_font_size("font_size", "CheckBox", 13)

	return t


static func _circle_icon(radius: int, color: Color) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(radius, radius)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= radius - 0.5:
				img.set_pixel(x, y, color)
			elif d <= radius + 0.5:
				img.set_pixel(x, y, Color(color, 0.5))
	return ImageTexture.create_from_image(img)


static func heading(text: String, size: int = 11, color: Color = MUTED) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func separator(vertical: bool = false) -> Control:
	var c := ColorRect.new()
	c.color = LINE
	if vertical:
		c.custom_minimum_size = Vector2(1, 0)
	else:
		c.custom_minimum_size = Vector2(0, 1)
	return c
