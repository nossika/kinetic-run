class_name StartScreenPanel
extends Control

signal starter_ball_selected(ball_index: int)
signal seed_changed(seed_text: String)
signal randomize_seed_requested

var _seed_input: LineEdit = null
var _cards_row: HBoxContainer = null
var _suppress_seed_signal: bool = false
var _current_balls: Array[StarterBallDefinition] = []


static func _make_ball_preview_widget(def: StarterBallDefinition) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0.0, 92.0)

	var r_scale := clampf((def.radius if def != null else 0.55) / 0.58, 0.82, 1.18)
	var shape_t := def.shape_type if def != null else "sphere"
	var w := 68.0 * r_scale
	var h := 68.0 * r_scale
	var radius_px := int(round(h * 0.5))

	if shape_t == "rugby":
		w = 94.0 * r_scale
		h = 62.0 * r_scale
		radius_px = int(round(h * 0.5))
	elif shape_t == "capsule_roller":
		w = 100.0 * r_scale
		h = 56.0 * r_scale
		radius_px = int(round(h * 0.5))

	var mask_panel := Panel.new()
	mask_panel.custom_minimum_size = Vector2(w, h)
	mask_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var mask_sb := StyleBoxFlat.new()
	mask_sb.bg_color = def.accent_color if def != null else Color(0.92, 0.36, 0.30)
	mask_sb.set_corner_radius_all(radius_px)
	mask_sb.shadow_color = Color(0.18, 0.11, 0.06, 0.22)
	mask_sb.shadow_size = 5
	mask_sb.shadow_offset = Vector2(0.0, 3.0)
	mask_panel.add_theme_stylebox_override("panel", mask_sb)

	if DisplayServer.get_name() != "headless" and def != null:
		var tex := load(def.livery_texture_path) as Texture2D
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.modulate = def.primary_tint
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			mask_panel.add_child(tr)

	holder.add_child(mask_panel)
	return holder


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build_theme()
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.16, 0.28, 0.22)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_vb := VBoxContainer.new()
	root_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vb.add_theme_constant_override("separation", 14)
	center.add_child(root_vb)

	# 1. Header & Seed Panel
	var header_card := PanelContainer.new()
	header_card.custom_minimum_size = Vector2(760.0, 0.0)
	header_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header_card.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(
			UiTheme.CREAM_ELEVATED,
			Color(0.54, 0.36, 0.20, 0.96),
			22,
			3
		)
	)
	root_vb.add_child(header_card)

	var header_vb := VBoxContainer.new()
	header_vb.add_theme_constant_override("separation", 8)
	header_card.add_child(header_vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	title.text = "给我滚  ·  挑选你的初始玩具球"
	header_vb.add_child(title)

	var sub := Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", UiTheme.INK_MUTED)
	sub.text = "修改种子会同步刷新下方 3 颗候选球的形状、属性与涂装  ·  点击卡片或按 [1] [2] [3] 立即发车"
	header_vb.add_child(sub)

	var seed_row := HBoxContainer.new()
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 10)
	header_vb.add_child(seed_row)

	var seed_lbl := Label.new()
	seed_lbl.add_theme_font_size_override("font_size", 16)
	seed_lbl.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	seed_lbl.text = "本局种子："
	seed_row.add_child(seed_lbl)

	_seed_input = LineEdit.new()
	_seed_input.custom_minimum_size = Vector2(280.0, 38.0)
	_seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_input.placeholder_text = "输入数字 / 英文 / 中文口令"
	_seed_input.text_changed.connect(_on_seed_text_edited)
	_seed_input.text_submitted.connect(_on_seed_text_submitted)
	seed_row.add_child(_seed_input)

	var rand_btn := Button.new()
	rand_btn.text = "随机换号"
	rand_btn.focus_mode = Control.FOCUS_NONE
	rand_btn.custom_minimum_size = Vector2(128.0, 38.0)
	rand_btn.pressed.connect(func() -> void: randomize_seed_requested.emit())
	seed_row.add_child(rand_btn)

	# 2. 3 Starter Ball Cards Row
	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 18)
	root_vb.add_child(_cards_row)


func show_start_screen(seed_text: String, balls: Array[StarterBallDefinition]) -> void:
	visible = true
	refresh_options(seed_text, balls)


func refresh_options(seed_text: String, balls: Array[StarterBallDefinition]) -> void:
	_current_balls = balls
	if _seed_input != null and _seed_input.text != seed_text:
		_suppress_seed_signal = true
		var prev_caret := _seed_input.caret_column
		_seed_input.text = seed_text
		_seed_input.caret_column = mini(prev_caret, seed_text.length())
		_suppress_seed_signal = false

	if _cards_row == null:
		return
	for child in _cards_row.get_children():
		child.queue_free()

	for idx in range(balls.size()):
		var def := balls[idx]
		var card := _build_ball_card(idx, def)
		_cards_row.add_child(card)


func _build_ball_card(idx: int, def: StarterBallDefinition) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(316.0, 382.0)
	var border_col := def.accent_color.darkened(0.18)
	border_col.a = 0.96
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.make_storybook_card_style(UiTheme.CREAM_ELEVATED, border_col, 22, 3)
	)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	card.add_child(vb)

	vb.add_child(_make_ball_preview_widget(def))

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	name_lbl.text = def.display_name
	vb.add_child(name_lbl)

	var tag_lbl := Label.new()
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_size_override("font_size", 14)
	tag_lbl.add_theme_color_override("font_color", def.accent_color.darkened(0.22))
	tag_lbl.text = "【%s】 %s" % [def.shape_label, def.tagline]
	vb.add_child(tag_lbl)

	var stats_vb := VBoxContainer.new()
	stats_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_vb.add_theme_constant_override("separation", 6)
	vb.add_child(stats_vb)

	_add_stat_bar_row(stats_vb, "重量", "%0.1f kg" % def.mass, clampf((def.mass - 0.8) / 2.8, 0.10, 1.0), Color(0.84, 0.44, 0.24))
	_add_stat_bar_row(stats_vb, "大小", "R %0.2f m" % def.radius, clampf((def.radius - 0.42) / 0.34, 0.10, 1.0), Color(0.24, 0.58, 0.88))
	_add_stat_bar_row(stats_vb, "弹性", "%d%%" % int(round(def.bounce * 100.0)), clampf(def.bounce, 0.10, 1.0), Color(0.20, 0.72, 0.46))
	_add_stat_bar_row(stats_vb, "摩擦", "%d%%" % int(round(def.friction * 100.0)), clampf(def.friction, 0.10, 1.0), Color(0.88, 0.62, 0.18))

	var pick_btn := Button.new()
	pick_btn.text = "选它出发 [%d]" % (idx + 1)
	pick_btn.custom_minimum_size = Vector2(0.0, 42.0)
	pick_btn.pressed.connect(func() -> void: _pick(idx))
	vb.add_child(pick_btn)

	return card


func _add_stat_bar_row(
	parent: VBoxContainer,
	label_txt: String,
	val_txt: String,
	ratio: float,
	fill_col: Color
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var k_lbl := Label.new()
	k_lbl.custom_minimum_size = Vector2(42.0, 0.0)
	k_lbl.add_theme_font_size_override("font_size", 14)
	k_lbl.add_theme_color_override("font_color", UiTheme.INK_MUTED)
	k_lbl.text = label_txt
	row.add_child(k_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = ratio * 100.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0.0, 11.0)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill_col
	sb_fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", sb_fill)
	row.add_child(bar)

	var v_lbl := Label.new()
	v_lbl.custom_minimum_size = Vector2(68.0, 0.0)
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v_lbl.add_theme_font_size_override("font_size", 14)
	v_lbl.add_theme_color_override("font_color", UiTheme.INK_PRIMARY)
	v_lbl.text = val_txt
	row.add_child(v_lbl)


func _on_seed_text_edited(new_text: String) -> void:
	if _suppress_seed_signal:
		return
	if new_text.strip_edges() != "":
		seed_changed.emit(new_text)


func _on_seed_text_submitted(submitted_text: String) -> void:
	if _seed_input != null and _seed_input.has_focus():
		_seed_input.release_focus()
	seed_changed.emit(submitted_text)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused is LineEdit or (_seed_input != null and _seed_input.has_focus()):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_1 or k == KEY_KP_1:
			_pick(0)
		elif k == KEY_2 or k == KEY_KP_2:
			_pick(1)
		elif k == KEY_3 or k == KEY_KP_3:
			_pick(2)


func _pick(idx: int) -> void:
	if idx < 0 or idx >= _current_balls.size():
		return
	visible = false
	starter_ball_selected.emit(idx)
