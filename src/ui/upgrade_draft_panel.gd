class_name UpgradeDraftPanel
extends Control

signal upgrade_chosen(index: int)

var _choices: Array[UpgradeDefinition] = []
var _selected_idx: int = 0
var _card_panels: Array[PanelContainer] = []
var _title_label: Label = null
var _cards_hbox: HBoxContainer = null


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

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 18)
	center.add_child(main_vbox)

	var header_pill := PanelContainer.new()
	header_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header_pill.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(
			UiTheme.CREAM_ELEVATED,
			Color(0.58, 0.80, 0.68, 0.94),
			22,
			2
		)
	)
	main_vbox.add_child(header_pill)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	header_pill.add_child(header_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", UiTheme.SAGE_ACCENT)
	_title_label.text = "冲线成功！选择 1 项物理原子强化"
	header_vbox.add_child(_title_label)

	var sub_hint := Label.new()
	sub_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_hint.add_theme_font_size_override("font_size", 15)
	sub_hint.add_theme_color_override("font_color", UiTheme.INK_MUTED)
	sub_hint.text = "按 [A/D] 或 [←/→] 切换卡片，[空格/回车] 确认，或直接按 [1 / 2 / 3] / 鼠标点击"
	header_vbox.add_child(sub_hint)

	_cards_hbox = HBoxContainer.new()
	_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_hbox.add_theme_constant_override("separation", 22)
	main_vbox.add_child(_cards_hbox)


func show_choices(cleared_level: int, choices: Array[UpgradeDefinition]) -> void:
	_choices = choices
	_selected_idx = 0
	visible = true
	if _title_label != null:
		_title_label.text = "第 %d 关突破！选择 1 项物理原子强化（下一关 %d m）" % [
			cleared_level,
			int(RunState.target_length_for_level(cleared_level + 1))
		]
	_rebuild_cards()


func _rebuild_cards() -> void:
	if _cards_hbox == null:
		return
	for child in _cards_hbox.get_children():
		child.queue_free()
	_card_panels.clear()

	for idx in range(_choices.size()):
		var def := _choices[idx]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(332.0, 270.0)
		_cards_hbox.add_child(card)
		_card_panels.append(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		card.add_child(vb)

		var badge := Label.new()
		badge.text = "[%d] %s  ·  %s" % [idx + 1, _rarity_text(def.rarity), _layer_text(def.layer)]
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", _rarity_ink_color(def.rarity))
		vb.add_child(badge)

		var name_lbl := Label.new()
		name_lbl.text = def.title
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
		vb.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = def.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", UiTheme.INK_MUTED)
		vb.add_child(desc_lbl)

		var pick_btn := Button.new()
		pick_btn.text = "装载此强化"
		pick_btn.custom_minimum_size = Vector2(0.0, 42.0)
		var captured := idx
		pick_btn.pressed.connect(func() -> void: _confirm(captured))
		vb.add_child(pick_btn)

	_refresh_selection_highlight()


func _refresh_selection_highlight() -> void:
	for i in range(_card_panels.size()):
		var def := _choices[i]
		var base_border := _rarity_border_color(def.rarity)
		var is_sel := (i == _selected_idx)
		var bg := Color(1.0, 0.98, 0.93, 0.99) if is_sel else Color(0.96, 0.92, 0.85, 0.95)
		var bw := 4 if is_sel else 2
		_card_panels[i].add_theme_stylebox_override(
			"panel",
			UiTheme.make_storybook_card_style(bg, base_border, 20, bw)
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _choices.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		var pk := (event as InputEventKey).physical_keycode
		if k == KEY_LEFT or pk == KEY_A:
			_selected_idx = (_selected_idx - 1 + _choices.size()) % _choices.size()
			_refresh_selection_highlight()
			accept_event()
		elif k == KEY_RIGHT or pk == KEY_D:
			_selected_idx = (_selected_idx + 1) % _choices.size()
			_refresh_selection_highlight()
			accept_event()
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_confirm(_selected_idx)
			accept_event()
		elif k == KEY_1 and _choices.size() >= 1:
			_confirm(0)
			accept_event()
		elif k == KEY_2 and _choices.size() >= 2:
			_confirm(1)
			accept_event()
		elif k == KEY_3 and _choices.size() >= 3:
			_confirm(2)
			accept_event()


func _confirm(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	visible = false
	upgrade_chosen.emit(idx)


static func _rarity_text(rarity: String) -> String:
	match rarity:
		"rare":
			return "稀有"
		"legendary":
			return "传奇"
		_:
			return "普通"


static func _layer_text(layer: String) -> String:
	match layer:
		"converter":
			return "物理转化器"
		"rule_breaker":
			return "规则与乘区放大器"
		_:
			return "底盘常数"


static func _rarity_border_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color(0.42, 0.68, 0.86)
		"legendary":
			return Color(0.88, 0.60, 0.24)
		_:
			return Color(0.72, 0.62, 0.50)


static func _rarity_ink_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color(0.22, 0.48, 0.68)
		"legendary":
			return Color(0.76, 0.44, 0.12)
		_:
			return Color(0.50, 0.40, 0.30)
