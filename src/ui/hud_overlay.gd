class_name HudOverlay
extends Control

signal seed_submitted(seed_text: String)
signal seed_dialog_toggled(is_open: bool)

var seed_input_enabled: bool = true

var _timer_label: Label = null
var _level_label: Label = null
var _speed_label: Label = null
var _momentum_label: Label = null
var _overload_label: Label = null
var _progress_bar: ProgressBar = null
var _respawn_banner: Label = null
var _controls_hint: Label = null
var _upgrades_label: Label = null

var _seed_label: Label = null
var _seed_btn: Button = null
var _left_thrust_badge: PanelContainer = null
var _left_thrust_label: Label = null
var _right_thrust_badge: PanelContainer = null
var _right_thrust_label: Label = null

var _seed_modal: Control = null
var _seed_line_edit: LineEdit = null
var _current_seed_text: String = ""

var _thrust_active_style: StyleBoxFlat = null
var _thrust_idle_style: StyleBoxFlat = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build_theme()
	_init_badge_styles()
	_build_layout()
	_build_seed_modal()
	update_thrust_indicators(0.0)


func _init_badge_styles() -> void:
	_thrust_active_style = UiTheme.make_panel_style(
		Color(0.06, 0.42, 0.58, 0.96),
		Color(0.24, 0.96, 1.0, 1.0),
		8,
		2
	)
	_thrust_active_style.content_margin_left = 10.0
	_thrust_active_style.content_margin_right = 10.0
	_thrust_active_style.content_margin_top = 4.0
	_thrust_active_style.content_margin_bottom = 4.0

	_thrust_idle_style = UiTheme.make_panel_style(
		Color(0.08, 0.11, 0.17, 0.62),
		Color(0.30, 0.38, 0.50, 0.45),
		8,
		1
	)
	_thrust_idle_style.content_margin_left = 10.0
	_thrust_idle_style.content_margin_right = 10.0
	_thrust_idle_style.content_margin_top = 4.0
	_thrust_idle_style.content_margin_bottom = 4.0


func _build_layout() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)

	var root_vbox := VBoxContainer.new()
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root_vbox)

	# 1. Top row: centered Timer/Thrust/Progress Panel + Seed Pill
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 12)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(top_row)

	var top_box := PanelContainer.new()
	top_box.custom_minimum_size = Vector2(460.0, 0.0)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.07, 0.10, 0.17, 0.86), Color(0.22, 0.68, 1.0, 0.90))
	)
	top_row.add_child(top_box)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 4)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(top_vbox)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
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
	_left_thrust_label.add_theme_font_size_override("font_size", 15)
	_left_thrust_label.text = "[ ◀ 左推 ]"
	_left_thrust_badge.add_child(_left_thrust_label)

	_timer_label = Label.new()
	_timer_label.custom_minimum_size = Vector2(148.0, 0.0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	_timer_label.text = "30.00 s"
	timer_thrust_row.add_child(_timer_label)

	_right_thrust_badge = PanelContainer.new()
	_right_thrust_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_thrust_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_thrust_row.add_child(_right_thrust_badge)

	_right_thrust_label = Label.new()
	_right_thrust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_thrust_label.add_theme_font_size_override("font_size", 15)
	_right_thrust_label.text = "[ 右推 ▶ ]"
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
	seed_pill.mouse_filter = Control.MOUSE_FILTER_PASS
	seed_pill.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.07, 0.10, 0.17, 0.86), Color(0.95, 0.76, 0.30, 0.88), 10, 2)
	)
	top_row.add_child(seed_pill)

	var seed_hbox := HBoxContainer.new()
	seed_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_hbox.add_theme_constant_override("separation", 10)
	seed_pill.add_child(seed_hbox)

	_seed_label = Label.new()
	_seed_label.add_theme_font_size_override("font_size", 15)
	_seed_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	_seed_label.text = "种子: ------"
	seed_hbox.add_child(_seed_label)

	_seed_btn = Button.new()
	_seed_btn.text = "填入种子 [N]"
	_seed_btn.focus_mode = Control.FOCUS_NONE
	_seed_btn.custom_minimum_size = Vector2(108.0, 30.0)
	_seed_btn.add_theme_font_size_override("font_size", 14)
	_seed_btn.pressed.connect(open_seed_dialog)
	seed_hbox.add_child(_seed_btn)

	# 2. Middle expanding area (holds centered Respawn alert banner when active)
	var mid_spacer := CenterContainer.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(mid_spacer)

	_respawn_banner = Label.new()
	_respawn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_banner.add_theme_font_size_override("font_size", 28)
	_respawn_banner.add_theme_color_override("font_color", Color(1.0, 0.38, 0.24))
	_respawn_banner.text = "坠出赛道！时空拉回中..."
	_respawn_banner.visible = false
	mid_spacer.add_child(_respawn_banner)

	# 3. Bottom row: Left Build/Controls Panel + Spacer + Right Speedometer Panel
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(bottom_row)

	var build_panel := PanelContainer.new()
	build_panel.custom_minimum_size = Vector2(540.0, 0.0)
	build_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.07, 0.10, 0.17, 0.84), Color(0.38, 0.54, 0.78, 0.82))
	)
	bottom_row.add_child(build_panel)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 4)
	b_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_panel.add_child(b_vbox)

	_controls_hint = Label.new()
	_controls_hint.add_theme_font_size_override("font_size", 15)
	_controls_hint.add_theme_color_override("font_color", Color(0.98, 0.91, 0.58))
	_controls_hint.text = "操控：按住 [A / ←] 左推   按住 [D / →] 右推（松手即停 · 可借斜坡/弹簧腾空穿环）"
	b_vbox.add_child(_controls_hint)

	_upgrades_label = Label.new()
	_upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrades_label.add_theme_font_size_override("font_size", 14)
	_upgrades_label.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))
	_upgrades_label.text = "当前构筑：初始钨钢球（冲过终点三选一强化）"
	b_vbox.add_child(_upgrades_label)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(h_spacer)

	var speed_panel := PanelContainer.new()
	speed_panel.custom_minimum_size = Vector2(280.0, 0.0)
	speed_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.07, 0.10, 0.17, 0.86), Color(0.20, 0.92, 0.78, 0.88))
	)
	bottom_row.add_child(speed_panel)

	var sp_vbox := VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 4)
	sp_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_momentum_label.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	_momentum_label.text = "动量 P: 0.0  |  ● 1.5 kg"
	sp_vbox.add_child(_momentum_label)

	_overload_label = Label.new()
	_overload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overload_label.add_theme_font_size_override("font_size", 15)
	_overload_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.28))
	_overload_label.text = "冲量乘区: x1.00"
	sp_vbox.add_child(_overload_label)


func _build_seed_modal() -> void:
	_seed_modal = Control.new()
	_seed_modal.name = "SeedModal"
	_seed_modal.visible = false
	_seed_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_seed_modal)
	_seed_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.07, 0.12, 0.46)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_seed_modal.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_seed_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460.0, 215.0)
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.08, 0.11, 0.19, 0.97), Color(0.96, 0.76, 0.28, 0.95), 14, 3)
	)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	title.text = "填入挑战种子（比赛已暂停）"
	vb.add_child(title)

	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	desc.text = "输入数字、英文或中文口令从第 1 关开跑（留空则生成新随机种子）"
	vb.add_child(desc)

	_seed_line_edit = LineEdit.new()
	_seed_line_edit.placeholder_text = "例如：TABLETOP2026 / 888888 / 给我滚"
	_seed_line_edit.custom_minimum_size = Vector2(0.0, 42.0)
	_seed_line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_line_edit.text_submitted.connect(_on_seed_text_submitted)
	vb.add_child(_seed_line_edit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vb.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "按此种子开局（回车）"
	confirm_btn.custom_minimum_size = Vector2(185.0, 40.0)
	confirm_btn.pressed.connect(_confirm_seed_dialog)
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消继续（Esc）"
	cancel_btn.custom_minimum_size = Vector2(150.0, 40.0)
	cancel_btn.pressed.connect(func() -> void: close_seed_dialog(true))
	btn_row.add_child(cancel_btn)


func is_seed_dialog_open() -> bool:
	return _seed_modal != null and _seed_modal.visible


func open_seed_dialog() -> void:
	if not seed_input_enabled or _seed_modal == null or _seed_modal.visible:
		return
	_seed_modal.visible = true
	if _seed_line_edit != null:
		_seed_line_edit.text = _current_seed_text
		_seed_line_edit.grab_focus()
		_seed_line_edit.select_all()
	seed_dialog_toggled.emit(true)


func close_seed_dialog(emit_toggle: bool = true) -> void:
	if _seed_modal == null or not _seed_modal.visible:
		return
	_seed_modal.visible = false
	if _seed_line_edit != null and _seed_line_edit.has_focus():
		_seed_line_edit.release_focus()
	if emit_toggle:
		seed_dialog_toggled.emit(false)


func _confirm_seed_dialog() -> void:
	var raw_txt := _seed_line_edit.text if _seed_line_edit != null else ""
	close_seed_dialog(false)
	seed_submitted.emit(raw_txt)


func _on_seed_text_submitted(submitted_text: String) -> void:
	close_seed_dialog(false)
	seed_submitted.emit(submitted_text)


func _input(event: InputEvent) -> void:
	if not is_seed_dialog_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			close_seed_dialog(true)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not seed_input_enabled or is_seed_dialog_open():
		return
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused is LineEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		var pk := (event as InputEventKey).physical_keycode
		if k == KEY_N or pk == KEY_N:
			open_seed_dialog()
			accept_event()


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
		Color(0.96, 1.0, 1.0, 1.0) if left_on else Color(0.54, 0.62, 0.72, 0.68)
	)

	_right_thrust_badge.add_theme_stylebox_override(
		"panel",
		_thrust_active_style if right_on else _thrust_idle_style
	)
	_right_thrust_label.add_theme_color_override(
		"font_color",
		Color(0.96, 1.0, 1.0, 1.0) if right_on else Color(0.54, 0.62, 0.72, 0.68)
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
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25))
	else:
		_timer_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))

	if seed_text != "":
		_current_seed_text = seed_text
		if _seed_label != null:
			_seed_label.text = "种子: %s" % seed_text

	if _seed_btn != null:
		_seed_btn.disabled = not seed_input_enabled

	update_thrust_indicators(0.0 if respawning else thrust_axis)

	_progress_bar.value = clampf(progress_ratio, 0.0, 1.0) * 100.0
	_speed_label.text = "%d km/h" % int(round(speed_mps * 3.6))
	_momentum_label.text = "动量 P: %0.1f  |  ● %0.1f kg" % [speed_mps * mass_kg, mass_kg]
	if overload_stacks > 0:
		_overload_label.text = "过载 %d 层  |  冲量乘区 x%0.2f" % [overload_stacks, impulse_mult]
	else:
		_overload_label.text = "冲量乘区: x%0.2f" % impulse_mult

	_respawn_banner.visible = respawning
	_upgrades_label.text = upgrade_summary
