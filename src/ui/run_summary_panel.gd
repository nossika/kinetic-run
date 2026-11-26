class_name RunSummaryPanel
extends Control

signal restart_requested
signal restart_same_seed_requested
signal restart_custom_seed_requested(seed_text: String)

var _stats_label: Label = null
var _custom_seed_input: LineEdit = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build_theme()
	visible = false
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.20, 0.14, 0.10, 0.56)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(580.0, 420.0)
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
	restart_btn.text = "新随机种子挑战（空格 / 回车）"
	restart_btn.custom_minimum_size = Vector2(0.0, 44.0)
	restart_btn.pressed.connect(_trigger_restart)
	vb.add_child(restart_btn)

	var same_seed_btn := Button.new()
	same_seed_btn.text = "同种子重玩本局"
	same_seed_btn.custom_minimum_size = Vector2(0.0, 42.0)
	same_seed_btn.pressed.connect(_trigger_same_seed_restart)
	vb.add_child(same_seed_btn)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 10)
	vb.add_child(custom_row)

	_custom_seed_input = LineEdit.new()
	_custom_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_seed_input.custom_minimum_size = Vector2(0.0, 42.0)
	_custom_seed_input.placeholder_text = "输入自定义种子（数字 / 英文 / 中文口令）"
	_custom_seed_input.text_submitted.connect(_on_custom_seed_submitted)
	custom_row.add_child(_custom_seed_input)

	var custom_btn := Button.new()
	custom_btn.text = "按此种子开局"
	custom_btn.custom_minimum_size = Vector2(148.0, 42.0)
	custom_btn.pressed.connect(_trigger_custom_seed_restart)
	custom_row.add_child(custom_btn)


func show_summary(run_state: RunState, build_text: String) -> void:
	visible = true
	if _custom_seed_input != null:
		_custom_seed_input.text = ""
		if _custom_seed_input.has_focus():
			_custom_seed_input.release_focus()
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
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused is LineEdit or (_custom_seed_input != null and _custom_seed_input.has_focus()):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_trigger_restart()
			accept_event()


func _trigger_restart() -> void:
	if _custom_seed_input != null and _custom_seed_input.has_focus():
		_custom_seed_input.release_focus()
	visible = false
	restart_requested.emit()


func _trigger_same_seed_restart() -> void:
	if _custom_seed_input != null and _custom_seed_input.has_focus():
		_custom_seed_input.release_focus()
	visible = false
	restart_same_seed_requested.emit()


func _on_custom_seed_submitted(submitted_text: String) -> void:
	if _custom_seed_input != null and _custom_seed_input.has_focus():
		_custom_seed_input.release_focus()
	visible = false
	restart_custom_seed_requested.emit(submitted_text)


func _trigger_custom_seed_restart() -> void:
	var txt := _custom_seed_input.text if _custom_seed_input != null else ""
	_on_custom_seed_submitted(txt)
