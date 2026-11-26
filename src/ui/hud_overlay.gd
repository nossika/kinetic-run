class_name HudOverlay
extends Control

var _timer_label: Label = null
var _level_label: Label = null
var _speed_label: Label = null
var _momentum_label: Label = null
var _overload_label: Label = null
var _progress_bar: ProgressBar = null
var _respawn_pill: PanelContainer = null
var _respawn_banner: Label = null
var _controls_hint: Label = null
var _upgrades_label: Label = null

var _seed_label: Label = null
var _left_thrust_badge: PanelContainer = null
var _left_thrust_label: Label = null
var _right_thrust_badge: PanelContainer = null
var _right_thrust_label: Label = null

var _thrust_active_style: StyleBoxFlat = null
var _thrust_idle_style: StyleBoxFlat = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build_theme()
	_init_badge_styles()
	_build_layout()
	update_thrust_indicators(0.0)


func _init_badge_styles() -> void:
	_thrust_active_style = UiTheme.make_storybook_card_style(
		Color(0.24, 0.76, 0.56, 0.96),
		Color(0.16, 0.56, 0.40, 0.96),
		12,
		2
	)
	_thrust_active_style.shadow_size = 2
	_thrust_active_style.content_margin_left = 11.0
	_thrust_active_style.content_margin_right = 11.0
	_thrust_active_style.content_margin_top = 4.0
	_thrust_active_style.content_margin_bottom = 4.0

	_thrust_idle_style = UiTheme.make_storybook_card_style(
		Color(0.93, 0.88, 0.79, 0.76),
		Color(0.80, 0.70, 0.58, 0.55),
		12,
		1
	)
	_thrust_idle_style.shadow_size = 0
	_thrust_idle_style.content_margin_left = 11.0
	_thrust_idle_style.content_margin_right = 11.0
	_thrust_idle_style.content_margin_top = 4.0
	_thrust_idle_style.content_margin_bottom = 4.0


func _build_layout() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 18)

	var root_vbox := VBoxContainer.new()
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root_vbox)

	# 1. Top row: centered warm parchment Timer/Progress Card + Read-only Seed Pill
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 12)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(top_row)

	var top_box := PanelContainer.new()
	top_box.custom_minimum_size = Vector2(450.0, 0.0)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(UiTheme.CREAM_BG, UiTheme.WALNUT_BORDER, 20, 2)
	)
	top_row.add_child(top_box)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 5)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(top_vbox)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 15)
	_level_label.add_theme_color_override("font_color", UiTheme.INK_MUTED)
	_level_label.text = "给我滚  ·  第 1 关  |  剩余距离 130 m"
	top_vbox.add_child(_level_label)

	var timer_thrust_row := HBoxContainer.new()
	timer_thrust_row.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_thrust_row.add_theme_constant_override("separation", 12)
	timer_thrust_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(timer_thrust_row)

	_left_thrust_badge = PanelContainer.new()
	_left_thrust_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left_thrust_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_thrust_row.add_child(_left_thrust_badge)

	_left_thrust_label = Label.new()
	_left_thrust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_thrust_label.add_theme_font_size_override("font_size", 14)
	_left_thrust_label.text = "◀ 左推"
	_left_thrust_badge.add_child(_left_thrust_label)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 32)
	_timer_label.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	_timer_label.text = "30.00 s"
	timer_thrust_row.add_child(_timer_label)

	_right_thrust_badge = PanelContainer.new()
	_right_thrust_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_thrust_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_thrust_row.add_child(_right_thrust_badge)

	_right_thrust_label = Label.new()
	_right_thrust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_thrust_label.add_theme_font_size_override("font_size", 14)
	_right_thrust_label.text = "右推 ▶"
	_right_thrust_badge.add_child(_right_thrust_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(_progress_bar)

	var seed_pill := PanelContainer.new()
	seed_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	seed_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_pill.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(
			Color(0.99, 0.96, 0.89, 0.92),
			Color(0.84, 0.67, 0.42, 0.88),
			18,
			2
		)
	)
	top_row.add_child(seed_pill)

	_seed_label = Label.new()
	_seed_label.add_theme_font_size_override("font_size", 14)
	_seed_label.add_theme_color_override("font_color", Color(0.46, 0.33, 0.18))
	_seed_label.text = "种子: ------"
	seed_pill.add_child(_seed_label)

	# 2. Middle expanding area (holds soft rounded Respawn pill when active)
	var mid_spacer := CenterContainer.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(mid_spacer)

	_respawn_pill = PanelContainer.new()
	_respawn_pill.visible = false
	_respawn_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_respawn_pill.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(
			Color(0.99, 0.94, 0.90, 0.95),
			Color(0.88, 0.52, 0.42, 0.92),
			20,
			2
		)
	)
	mid_spacer.add_child(_respawn_pill)

	_respawn_banner = Label.new()
	_respawn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_banner.add_theme_font_size_override("font_size", 22)
	_respawn_banner.add_theme_color_override("font_color", UiTheme.CORAL_ALERT)
	_respawn_banner.text = "掉出跑道啦 · 轻柔拉回中..."
	_respawn_pill.add_child(_respawn_banner)

	# 3. Bottom row: Left Build/Controls Card + Spacer + Right Speedometer Card
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(bottom_row)

	var build_panel := PanelContainer.new()
	build_panel.custom_minimum_size = Vector2(510.0, 0.0)
	build_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(UiTheme.CREAM_BG, UiTheme.WALNUT_BORDER, 18, 2)
	)
	bottom_row.add_child(build_panel)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 4)
	b_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_panel.add_child(b_vbox)

	_controls_hint = Label.new()
	_controls_hint.add_theme_font_size_override("font_size", 14)
	_controls_hint.add_theme_color_override("font_color", UiTheme.INK_MUTED)
	_controls_hint.text = "操控：按住 [A / ←] 左推  ·  [D / →] 右推（松手即停 · 可借斜坡与弹簧跃向云台）"
	b_vbox.add_child(_controls_hint)

	_upgrades_label = Label.new()
	_upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrades_label.add_theme_font_size_override("font_size", 14)
	_upgrades_label.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	_upgrades_label.text = "当前构筑：初始玩具球（冲过终点三选一强化）"
	b_vbox.add_child(_upgrades_label)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(h_spacer)

	var speed_panel := PanelContainer.new()
	speed_panel.custom_minimum_size = Vector2(265.0, 0.0)
	speed_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(
			UiTheme.CREAM_BG,
			Color(0.56, 0.78, 0.68, 0.90),
			18,
			2
		)
	)
	bottom_row.add_child(speed_panel)

	var sp_vbox := VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 3)
	sp_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_panel.add_child(sp_vbox)

	_speed_label = Label.new()
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_label.add_theme_font_size_override("font_size", 28)
	_speed_label.add_theme_color_override("font_color", UiTheme.SAGE_ACCENT)
	_speed_label.text = "0 km/h"
	sp_vbox.add_child(_speed_label)

	_momentum_label = Label.new()
	_momentum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_momentum_label.add_theme_font_size_override("font_size", 14)
	_momentum_label.add_theme_color_override("font_color", UiTheme.INK_MUTED)
	_momentum_label.text = "动量 P: 0.0  |  ● 1.5 kg"
	sp_vbox.add_child(_momentum_label)

	_overload_label = Label.new()
	_overload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overload_label.add_theme_font_size_override("font_size", 14)
	_overload_label.add_theme_color_override("font_color", UiTheme.AMBER_ACCENT)
	_overload_label.text = "冲量乘区: x1.00"
	sp_vbox.add_child(_overload_label)


func update_thrust_indicators(thrust_axis: float) -> void:
	if _left_thrust_badge == null or _right_thrust_badge == null:
		return
	var left_on := thrust_axis < -0.05
	var right_on := thrust_axis > 0.05

	_left_thrust_badge.add_theme_stylebox_override(
		"panel",
		_thrust_active_style if left_on else _thrust_idle_style
	)
	_left_thrust_label.add_theme_color_override(
		"font_color",
		Color(0.99, 1.0, 0.98, 1.0) if left_on else Color(0.52, 0.42, 0.32, 0.78)
	)

	_right_thrust_badge.add_theme_stylebox_override(
		"panel",
		_thrust_active_style if right_on else _thrust_idle_style
	)
	_right_thrust_label.add_theme_color_override(
		"font_color",
		Color(0.99, 1.0, 0.98, 1.0) if right_on else Color(0.52, 0.42, 0.32, 0.78)
	)


func update_hud(
	level: int,
	time_left: float,
	speed_mps: float,
	mass_kg: float,
	progress_ratio: float,
	overload_stacks: int,
	impulse_mult: float,
	respawning: bool,
	upgrade_summary: String,
	seed_text: String = "",
	thrust_axis: float = 0.0
) -> void:
	if _timer_label == null:
		return
	_level_label.text = "给我滚  ·  第 %d 关  |  剩余距离 %d m" % [
		level,
		maxi(0, int(round((1.0 - clampf(progress_ratio, 0.0, 1.0)) * RunState.target_length_for_level(level))))
	]
	_timer_label.text = "%0.2f s" % time_left
	if time_left <= 8.0:
		_timer_label.add_theme_color_override("font_color", UiTheme.CORAL_ALERT)
	else:
		_timer_label.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)

	if seed_text != "" and _seed_label != null:
		_seed_label.text = "种子: %s" % seed_text

	update_thrust_indicators(0.0 if respawning else thrust_axis)

	_progress_bar.value = clampf(progress_ratio, 0.0, 1.0) * 100.0
	_speed_label.text = "%d km/h" % int(round(speed_mps * 3.6))
	_momentum_label.text = "动量 P: %0.1f  |  ● %0.1f kg" % [speed_mps * mass_kg, mass_kg]
	if overload_stacks > 0:
		_overload_label.text = "过载 %d 层  |  冲量乘区 x%0.2f" % [overload_stacks, impulse_mult]
	else:
		_overload_label.text = "冲量乘区: x%0.2f" % impulse_mult

	if _respawn_pill != null:
		_respawn_pill.visible = respawning
	_respawn_banner.visible = respawning
	_upgrades_label.text = upgrade_summary
