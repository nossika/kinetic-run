class_name UiTheme
extends RefCounted

const BUNDLED_FONT_PATH: String = "res://assets/fonts/game_ui_zh.ttf"

const CREAM_BG := Color(0.98, 0.95, 0.89, 0.92)
const CREAM_ELEVATED := Color(0.99, 0.97, 0.92, 0.97)
const WALNUT_BORDER := Color(0.77, 0.65, 0.51, 0.88)
const INK_PRIMARY := Color(0.27, 0.19, 0.13, 1.0)
const INK_MUTED := Color(0.47, 0.37, 0.28, 1.0)
const SAGE_ACCENT := Color(0.20, 0.58, 0.44, 1.0)
const AMBER_ACCENT := Color(0.76, 0.45, 0.16, 1.0)
const CORAL_ALERT := Color(0.84, 0.34, 0.26, 1.0)


static func build_theme() -> Theme:
	var theme := Theme.new()
	if DisplayServer.get_name() != "headless":
		var bundled_font: Font = load(BUNDLED_FONT_PATH) as Font
		if bundled_font != null:
			theme.default_font = bundled_font
		else:
			var sys_font := SystemFont.new()
			sys_font.font_names = PackedStringArray([
				"PingFang SC",
				"Microsoft YaHei UI",
				"Microsoft YaHei",
				"Noto Sans CJK SC",
				"WenQuanYi Micro Hei",
				"sans-serif",
			])
			theme.default_font = sys_font
		theme.default_font_size = 18

	# Rounded warm almond clay Button styles
	var btn_normal := _make_control_box(Color(0.95, 0.89, 0.79, 0.96), Color(0.76, 0.63, 0.48, 0.92), 14, 2)
	btn_normal.shadow_color = Color(0.28, 0.19, 0.12, 0.12)
	btn_normal.shadow_size = 4
	btn_normal.shadow_offset = Vector2(0.0, 2.0)

	var btn_hover := _make_control_box(Color(0.99, 0.95, 0.87, 0.98), Color(0.44, 0.74, 0.60, 0.95), 14, 2)
	btn_hover.shadow_color = Color(0.28, 0.19, 0.12, 0.16)
	btn_hover.shadow_size = 5
	btn_hover.shadow_offset = Vector2(0.0, 2.0)

	var btn_pressed := _make_control_box(Color(0.89, 0.81, 0.69, 0.98), Color(0.68, 0.54, 0.40, 0.95), 14, 2)
	var btn_disabled := _make_control_box(Color(0.93, 0.90, 0.84, 0.70), Color(0.82, 0.76, 0.68, 0.60), 14, 1)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_hover)
	theme.set_color("font_color", "Button", INK_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color(0.18, 0.42, 0.32))
	theme.set_color("font_pressed_color", "Button", INK_PRIMARY)
	theme.set_color("font_disabled_color", "Button", Color(0.58, 0.50, 0.42, 0.65))

	# Rounded inset parchment LineEdit styles
	var edit_normal := _make_control_box(Color(1.0, 0.98, 0.94, 0.96), Color(0.78, 0.66, 0.52, 0.88), 12, 2)
	var edit_focus := _make_control_box(Color(1.0, 0.99, 0.96, 1.0), Color(0.42, 0.74, 0.60, 0.96), 12, 2)
	theme.set_stylebox("normal", "LineEdit", edit_normal)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_color("font_color", "LineEdit", INK_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.56, 0.46, 0.36, 0.72))
	theme.set_color("caret_color", "LineEdit", SAGE_ACCENT)

	# Rounded capsule ProgressBar styles
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.90, 0.84, 0.74, 0.88)
	pb_bg.set_corner_radius_all(8)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.42, 0.79, 0.64, 0.96)
	pb_fill.set_corner_radius_all(8)

	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)

	return theme


static func _make_control_box(
	bg_color: Color,
	border_color: Color,
	corner_radius: int,
	border_width: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


static func make_storybook_card_style(
	bg_color: Color = CREAM_BG,
	border_color: Color = WALNUT_BORDER,
	corner_radius: int = 18,
	border_width: int = 2
) -> StyleBoxFlat:
	return make_panel_style(bg_color, border_color, corner_radius, border_width)


static func make_panel_style(
	bg_color: Color,
	border_color: Color,
	corner_radius: int = 18,
	border_width: int = 2
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.shadow_color = Color(0.26, 0.18, 0.11, 0.13)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0.0, 3.0)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb
