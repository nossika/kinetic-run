class_name HudOverlay
extends Control

var _timer_label: Label = null
var _level_label: Label = null
var _speed_label: Label = null
var _momentum_label: Label = null
var _overload_label: Label = null
var _progress_bar: ProgressBar = null
var _respawn_banner: Label = null
var _controls_hint: Label = null
var _upgrades_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build_theme()
	_build_layout()


func _build_layout() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)

	var root_vbox := VBoxContainer.new()
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root_vbox)

	# 1. Top row: centered Timer & Progress Panel
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(top_row)

	var top_box := PanelContainer.new()
	top_box.custom_minimum_size = Vector2(430.0, 0.0)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.05, 0.08, 0.15, 0.86), Color(0.22, 0.68, 1.0, 0.9))
	)
	top_row.add_child(top_box)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 4)
	top_box.add_child(top_vbox)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", Color(0.68, 0.88, 1.0))
	_level_label.text = "给我滚  ·  第 1 关  |  剩余距离 130 m"
	top_vbox.add_child(_level_label)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_timer_label.text = "30.00 s"
	top_vbox.add_child(_timer_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 12.0)
	top_vbox.add_child(_progress_bar)

	# 2. Middle expanding area (holds centered Respawn alert banner when active)
	var mid_spacer := CenterContainer.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(mid_spacer)

	_respawn_banner = Label.new()
	_respawn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_banner.add_theme_font_size_override("font_size", 28)
	_respawn_banner.add_theme_color_override("font_color", Color(1.0, 0.42, 0.28))
	_respawn_banner.text = "坠出赛道！时空拉回中..."
	_respawn_banner.visible = false
	mid_spacer.add_child(_respawn_banner)

	# 3. Bottom row: Left Build/Controls Panel + Spacer + Right Speedometer Panel
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(bottom_row)

	var build_panel := PanelContainer.new()
	build_panel.custom_minimum_size = Vector2(460.0, 0.0)
	build_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.05, 0.08, 0.16, 0.82), Color(0.35, 0.50, 0.75, 0.78))
	)
	bottom_row.add_child(build_panel)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 4)
	build_panel.add_child(b_vbox)

	_controls_hint = Label.new()
	_controls_hint.add_theme_font_size_override("font_size", 15)
	_controls_hint.add_theme_color_override("font_color", Color(0.95, 0.90, 0.58))
	_controls_hint.text = "操控：[A / ←] 左倾世界   [D / →] 右倾世界（借坡与机关冲过终点）"
	b_vbox.add_child(_controls_hint)

	_upgrades_label = Label.new()
	_upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrades_label.add_theme_font_size_override("font_size", 14)
	_upgrades_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	_upgrades_label.text = "当前构筑：初始钨钢球（冲过终点三选一强化）"
	b_vbox.add_child(_upgrades_label)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(h_spacer)

	var speed_panel := PanelContainer.new()
	speed_panel.custom_minimum_size = Vector2(270.0, 0.0)
	speed_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.05, 0.08, 0.16, 0.86), Color(0.20, 0.92, 0.78, 0.85))
	)
	bottom_row.add_child(speed_panel)

	var sp_vbox := VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 4)
	speed_panel.add_child(sp_vbox)

	_speed_label = Label.new()
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_label.add_theme_font_size_override("font_size", 30)
	_speed_label.add_theme_color_override("font_color", Color(0.32, 1.0, 0.86))
	_speed_label.text = "0 km/h"
	sp_vbox.add_child(_speed_label)

	_momentum_label = Label.new()
	_momentum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_momentum_label.add_theme_font_size_override("font_size", 15)
	_momentum_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	_momentum_label.text = "动量 P: 0.0  |  质量: 1.5 kg"
	sp_vbox.add_child(_momentum_label)

	_overload_label = Label.new()
	_overload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overload_label.add_theme_font_size_override("font_size", 15)
	_overload_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.25))
	_overload_label.text = "冲量乘区: x1.00"
	sp_vbox.add_child(_overload_label)


func update_hud(
	level: int,
	time_left: float,
	speed_mps: float,
	mass_kg: float,
	progress_ratio: float,
	overload_stacks: int,
	impulse_mult: float,
	respawning: bool,
	upgrade_summary: String
) -> void:
	if _timer_label == null:
		return
	_level_label.text = "给我滚  ·  第 %d 关  |  剩余距离 %d m" % [
		level,
		maxi(0, int(round((1.0 - clampf(progress_ratio, 0.0, 1.0)) * RunState.target_length_for_level(level))))
	]
	_timer_label.text = "%0.2f s" % time_left
	if time_left <= 8.0:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25))
	else:
		_timer_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))

	_progress_bar.value = clampf(progress_ratio, 0.0, 1.0) * 100.0
	_speed_label.text = "%d km/h" % int(round(speed_mps * 3.6))
	_momentum_label.text = "动量 P: %0.1f  |  质量: %0.1f kg" % [speed_mps * mass_kg, mass_kg]
	if overload_stacks > 0:
		_overload_label.text = "过载 %d 层  |  冲量乘区 x%0.2f" % [overload_stacks, impulse_mult]
	else:
		_overload_label.text = "冲量乘区: x%0.2f" % impulse_mult

	_respawn_banner.visible = respawning
	_upgrades_label.text = upgrade_summary
