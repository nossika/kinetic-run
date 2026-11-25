class_name UiTheme
extends RefCounted

const BUNDLED_FONT_PATH: String = "res://assets/fonts/game_ui_zh.ttf"


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
	return theme


static func make_panel_style(
	bg_color: Color,
	border_color: Color,
	corner_radius: int = 10,
	border_width: int = 2
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb
