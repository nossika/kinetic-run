class_name RunSummaryPanel
extends Control

signal restart_requested

var _stats_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build_theme()
	visible = false
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.03, 0.08, 0.88)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560.0, 340.0)
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.make_panel_style(Color(0.09, 0.11, 0.20, 0.96), Color(1.0, 0.42, 0.32), 14, 3)
	)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.36))
	title.text = "时间耗尽 · 冲刺终止"
	vb.add_child(title)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	vb.add_child(_stats_label)

	var restart_btn := Button.new()
	restart_btn.text = "重新挑战（按 空格 / 回车）"
	restart_btn.custom_minimum_size = Vector2(0.0, 46.0)
	restart_btn.pressed.connect(func() -> void: _trigger_restart())
	vb.add_child(restart_btn)


func show_summary(run_state: RunState, build_text: String) -> void:
	visible = true
	if _stats_label != null:
		_stats_label.text = (
			"最终抵达关卡：第 %d 关（目标赛道 %d m）\n" % [
				run_state.current_level,
				int(RunState.target_length_for_level(run_state.current_level))
			]
			+ "本局峰值极速：%d km/h\n" % int(round(run_state.peak_speed_kmh))
			+ "最大单次动能：%d J\n" % int(round(run_state.max_kinetic_energy))
			+ "累计撞飞路障/怪物：%d 个\n\n" % run_state.total_smashed
			+ "%s" % build_text
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_trigger_restart()
			accept_event()


func _trigger_restart() -> void:
	visible = false
	restart_requested.emit()
