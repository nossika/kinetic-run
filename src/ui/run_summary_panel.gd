class_name RunSummaryPanel
extends Control

signal restart_requested
signal restart_same_seed_requested

var _stats_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build_theme()
	visible = false
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.16, 0.12, 0.09, 0.54)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560.0, 380.0)
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(
			UiTheme.CREAM_ELEVATED,
			Color(0.86, 0.54, 0.42, 0.94),
			22,
			3
		)
	)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.CORAL_ALERT)
	title.text = "时间耗尽 · 本趟滚滚旅程结束"
	vb.add_child(title)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_label.add_theme_font_size_override("font_size", 17)
	_stats_label.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	vb.add_child(_stats_label)

	var restart_btn := Button.new()
	restart_btn.text = "新随机种子 · 返回选球画面（空格 / 回车）"
	restart_btn.custom_minimum_size = Vector2(0.0, 44.0)
	restart_btn.pressed.connect(_trigger_restart)
	vb.add_child(restart_btn)

	var same_seed_btn := Button.new()
	same_seed_btn.text = "同种子 · 重新选球挑战"
	same_seed_btn.custom_minimum_size = Vector2(0.0, 42.0)
	same_seed_btn.pressed.connect(_trigger_same_seed_restart)
	vb.add_child(same_seed_btn)


func show_summary(run_state: RunState, build_text: String) -> void:
	visible = true
	if _stats_label != null:
		_stats_label.text = (
			"本局种子：%s\n" % run_state.seed_text
			+ "最终抵达关卡：第 %d 关（目标赛道 %d m）\n" % [
				run_state.current_level,
				int(RunState.target_length_for_level(run_state.current_level))
			]
			+ "本局峰值极速：%d km/h\n" % int(round(run_state.peak_speed_kmh))
			+ "最大单次动能：%d J\n" % int(round(run_state.max_kinetic_energy))
			+ "累计撞飞路障/小怪：%d 个\n\n" % run_state.total_smashed
			+ "%s" % build_text
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_trigger_restart()


func _trigger_restart() -> void:
	visible = false
	restart_requested.emit()


func _trigger_same_seed_restart() -> void:
	visible = false
	restart_same_seed_requested.emit()
