class_name StarterBallPreview3D
extends SubViewportContainer

const IDLE_ROLL_SPEED: float = 2.65
const HOVER_ROLL_SPEED: float = 5.80

var _viewport: SubViewport = null
var _world_root: Node3D = null
var _pedestal_trim: MeshInstance3D = null
var _stage_pivot: Node3D = null
var _roll_pivot: Node3D = null
var _ball_mesh: MeshInstance3D = null

var _ball_def: StarterBallDefinition = null
var _scale_ratio: float = 1.0
var _anim_time: float = 0.0
var _roll_angle: float = 0.35
var _is_hovered: bool = false
var _is_active: bool = true


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(276.0, 144.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_3d_stage()


func _build_3d_stage() -> void:
	if _viewport != null:
		return
	var is_headless := DisplayServer.get_name() == "headless"

	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(276, 144)
	if not is_headless:
		_viewport.msaa_3d = Viewport.MSAA_2X
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "PreviewWorldRoot"
	_viewport.add_child(_world_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.90
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.93, 1.0)
	env.ambient_light_energy = 0.42

	var world_env := WorldEnvironment.new()
	world_env.name = "PreviewEnvironment"
	world_env.environment = env
	_world_root.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-44.0, -34.0, 0.0)
	key_light.light_color = Color(1.0, 0.97, 0.90)
	key_light.light_energy = 0.98
	key_light.shadow_opacity = 0.72
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key_light.directional_shadow_max_distance = 10.0
	key_light.shadow_enabled = not is_headless
	_world_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "RimFillLight"
	fill_light.rotation_degrees = Vector3(-18.0, 142.0, 0.0)
	fill_light.light_color = Color(0.72, 0.86, 1.0)
	fill_light.light_energy = 0.34
	fill_light.shadow_enabled = false
	_world_root.add_child(fill_light)

	var cam := Camera3D.new()
	cam.name = "PreviewCamera"
	cam.fov = 34.0
	var eye := Vector3(0.0, 1.24, 3.12)
	var target := Vector3(0.0, 0.46, 0.0)
	cam.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	cam.current = true
	_world_root.add_child(cam)

	# Fixed-size beechwood turntable pedestal (top surface at y = 0.0) as scale reference
	var pedestal := MeshInstance3D.new()
	pedestal.name = "PedestalMesh"
	pedestal.position = Vector3(0.0, -0.07, 0.0)
	if not is_headless:
		var disc := ClayMeshBuilder.make_chamfered_cylinder(0.96, 1.02, 0.14, 0.038, 32)
		var wood_mat := MaterialLibrary.make_beechwood_material(Color(1.10, 1.04, 0.96))
		wood_mat.next_pass = MaterialLibrary.make_toon_outline_material(0.024)
		ClayMeshBuilder.assign_mesh(pedestal, disc, wood_mat)
	_world_root.add_child(pedestal)

	_pedestal_trim = MeshInstance3D.new()
	_pedestal_trim.name = "PedestalTrim"
	_pedestal_trim.position = Vector3(0.0, -0.10, 0.0)
	if not is_headless:
		var trim_mesh := ClayMeshBuilder.make_chamfered_cylinder(1.03, 1.05, 0.055, 0.02, 32)
		var trim_mat := MaterialLibrary.make_silicone_soft_material(Color(0.24, 0.64, 0.92), false)
		ClayMeshBuilder.assign_mesh(_pedestal_trim, trim_mesh, trim_mat)
	_world_root.add_child(_pedestal_trim)

	_stage_pivot = Node3D.new()
	_stage_pivot.name = "StagePivot"
	_world_root.add_child(_stage_pivot)

	_roll_pivot = Node3D.new()
	_roll_pivot.name = "RollPivot"
	_stage_pivot.add_child(_roll_pivot)

	_ball_mesh = MeshInstance3D.new()
	_ball_mesh.name = "BallMesh"
	_roll_pivot.add_child(_ball_mesh)


func setup_ball(def: StarterBallDefinition, phase_offset: float = 0.0) -> void:
	_build_3d_stage()
	_ball_def = def
	_anim_time = phase_offset
	_roll_angle = 0.35 + phase_offset * 0.6

	var r := def.radius if def != null else StatSheet.BASE_RADIUS
	_scale_ratio = r / StatSheet.BASE_RADIUS
	_roll_pivot.position = Vector3(0.0, r, 0.0)
	_roll_pivot.scale = Vector3.ONE * _scale_ratio

	PlayerBall3D.populate_ball_visual(_ball_mesh, def)

	if DisplayServer.get_name() != "headless" and _pedestal_trim != null and def != null:
		var trim_mat := MaterialLibrary.make_silicone_soft_material(def.accent_color, false)
		_pedestal_trim.material_override = trim_mat

	_apply_pose()


func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered


func set_preview_active(active: bool) -> void:
	_is_active = active
	set_process(active)
	if _viewport != null:
		if active and DisplayServer.get_name() != "headless":
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_preview_active() -> bool:
	return _is_active


func get_ball_scale_ratio() -> float:
	return _scale_ratio


func get_roll_angle() -> float:
	return _roll_angle


func get_ball_mesh_instance() -> MeshInstance3D:
	return _ball_mesh


func _process(delta: float) -> void:
	if not _is_active:
		return
	_advance_preview_anim(delta)


func _advance_preview_anim(delta: float) -> void:
	_anim_time += delta
	var speed := HOVER_ROLL_SPEED if _is_hovered else IDLE_ROLL_SPEED
	_roll_angle += delta * speed
	_apply_pose()


func _apply_pose() -> void:
	if _stage_pivot != null:
		_stage_pivot.rotation.y = deg_to_rad(25.0) + sin(_anim_time * 1.15) * deg_to_rad(22.0)
	if _roll_pivot != null:
		_roll_pivot.rotation.x = _roll_angle
