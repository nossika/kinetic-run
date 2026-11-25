class_name PlayerBall3D
extends RigidBody3D

signal synergy_actions_requested(actions: Dictionary)
signal target_smashed(world_pos: Vector3)
signal respawn_state_changed(respawning: bool)

const MAX_SPEED: float = 85.0
const FALL_Y_OFFSET: float = 8.0
const RESPAWN_DURATION: float = 1.2
const STUCK_SPEED_THRESHOLD: float = 0.6
const STUCK_DURATION: float = 1.8
const AIRBORNE_MIN_TIME: float = 0.22

var synergy_bus: PhysicsSynergyBus = null
var current_radius: float = 0.55
var safe_floor_y: float = 0.0
var last_safe_pos: Vector3 = Vector3(0.0, 0.8, -2.0)
var is_respawning: bool = false
var respawn_time_left: float = 0.0

var _slime_zone_count: int = 0
var _stuck_timer: float = 0.0
var _air_time: float = 0.0
var _peak_downward_speed: float = 0.0
var _rail_bounce_cooldown: float = 0.0
var _saved_velocity_pre_step: Vector3 = Vector3.ZERO

var _collision_shape: CollisionShape3D = null
var _sphere_shape: SphereShape3D = null
var _visual_root: Node3D = null
var _core_mesh: MeshInstance3D = null


func _ready() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false

	if physics_material_override == null:
		var mat := PhysicsMaterial.new()
		mat.friction = 0.42
		mat.bounce = 0.25
		physics_material_override = mat

	_build_nodes_if_needed()
	body_entered.connect(_on_body_entered)
	if synergy_bus != null:
		sync_from_stats()


func setup(p_bus: PhysicsSynergyBus) -> void:
	synergy_bus = p_bus
	continuous_cd = true
	if physics_material_override == null:
		var mat := PhysicsMaterial.new()
		mat.friction = 0.42
		mat.bounce = 0.25
		physics_material_override = mat
	_build_nodes_if_needed()
	sync_from_stats()


func _build_nodes_if_needed() -> void:
	if _collision_shape != null:
		return

	_sphere_shape = SphereShape3D.new()
	_sphere_shape.radius = current_radius
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = _sphere_shape
	add_child(_collision_shape)

	_visual_root = Node3D.new()
	add_child(_visual_root)

	_core_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.10
	sm.radial_segments = 24
	sm.rings = 16
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.16, 0.62, 1.0)
	core_mat.metallic = 0.55
	core_mat.roughness = 0.22
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.08, 0.35, 0.85)
	core_mat.emission_energy_multiplier = 0.8
	sm.material = core_mat
	RenderHelper.attach_mesh(_core_mesh, sm)
	_visual_root.add_child(_core_mesh)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.55, 0.98, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.35, 0.95, 1.0)
	ring_mat.emission_energy_multiplier = 1.8

	for idx in range(2):
		var band := MeshInstance3D.new()
		var ring_cyl := CylinderMesh.new()
		ring_cyl.top_radius = 0.57
		ring_cyl.bottom_radius = 0.57
		ring_cyl.height = 0.10
		ring_cyl.radial_segments = 24
		ring_cyl.material = ring_mat
		RenderHelper.attach_mesh(band, ring_cyl)
		if idx == 1:
			band.rotation_degrees.z = 90.0
		_visual_root.add_child(band)


func sync_from_stats() -> void:
	if synergy_bus == null:
		return
	var st := synergy_bus.stats
	mass = st.get_stat("mass")
	current_radius = st.get_stat("radius")
	if _sphere_shape != null:
		_sphere_shape.radius = current_radius
	if _visual_root != null:
		var scale_factor := current_radius / StatSheet.BASE_RADIUS
		_visual_root.scale = Vector3.ONE * scale_factor
	if physics_material_override != null:
		physics_material_override.bounce = st.get_stat("bounce")
	_refresh_damp()


func _refresh_damp() -> void:
	if synergy_bus == null:
		return
	var base_damp := synergy_bus.stats.get_stat("linear_damp")
	var extra_slime := 0.0
	if _slime_zone_count > 0 and not synergy_bus.stats.has_flag("immune_slime_damp"):
		extra_slime = 3.5
	linear_damp = base_damp + extra_slime
	angular_damp = 0.08


func set_in_slime_zone(inside: bool) -> void:
	if inside:
		_slime_zone_count += 1
	else:
		_slime_zone_count = maxi(0, _slime_zone_count - 1)
	_refresh_damp()


func reset_for_track(start_pos: Vector3) -> void:
	is_respawning = false
	respawn_time_left = 0.0
	_slime_zone_count = 0
	_stuck_timer = 0.0
	_air_time = 0.0
	_peak_downward_speed = 0.0
	_rail_bounce_cooldown = 0.0
	safe_floor_y = start_pos.y - current_radius
	last_safe_pos = start_pos
	freeze = false
	global_position = start_pos
	linear_velocity = Vector3(0.0, 0.0, -4.5)
	angular_velocity = Vector3.ZERO
	sync_from_stats()


func get_pre_step_speed() -> float:
	return maxf(linear_velocity.length(), _saved_velocity_pre_step.length())


func get_current_momentum() -> float:
	return mass * get_pre_step_speed()


func step_ball(delta: float, tilt_deg: float) -> void:
	_rail_bounce_cooldown = maxf(0.0, _rail_bounce_cooldown - delta)

	if is_respawning:
		respawn_time_left -= delta
		if respawn_time_left <= 0.0:
			is_respawning = false
			freeze = false
			global_position = last_safe_pos + Vector3(0.0, 1.2, 0.0)
			linear_velocity = Vector3(0.0, 0.0, -6.5)
			angular_velocity = Vector3.ZERO
			respawn_state_changed.emit(false)
		return

	# Check fall below track abyss
	if global_position.y < safe_floor_y - FALL_Y_OFFSET:
		is_respawning = true
		respawn_time_left = RESPAWN_DURATION
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
		respawn_state_changed.emit(true)
		return

	# Update safe respawn anchor when comfortably near floor center
	if global_position.y >= safe_floor_y - 0.5 and global_position.y <= safe_floor_y + current_radius + 0.6:
		if absf(global_position.x) <= 2.4:
			last_safe_pos = Vector3(0.0, safe_floor_y + current_radius + 0.2, global_position.z)

	# Airborne tracking & landing detection
	var height_above_floor := global_position.y - (safe_floor_y + current_radius)
	if height_above_floor > 0.38:
		_air_time += delta
		if -linear_velocity.y > _peak_downward_speed:
			_peak_downward_speed = -linear_velocity.y
		if synergy_bus != null:
			gravity_scale = synergy_bus.stats.get_stat("air_gravity_scale")
	else:
		gravity_scale = 1.0
		if _air_time >= AIRBORNE_MIN_TIME and _peak_downward_speed > 2.2:
			var land_ctx := make_event_context(_peak_downward_speed, Vector3.UP, global_position, 0, tilt_deg)
			if synergy_bus != null:
				var land_actions := synergy_bus.on_land(land_ctx)
				_consume_synergy_actions(land_actions)
		_air_time = 0.0
		_peak_downward_speed = 0.0

	# Extra forward drive multiplier if > 1.0
	if synergy_bus != null:
		var drive_mult := synergy_bus.stats.get_stat("forward_drive_mult")
		if absf(drive_mult - 1.0) > 0.01:
			var extra_accel := (drive_mult - 1.0) * 4.2
			apply_central_force(Vector3(0.0, 0.0, -extra_accel * mass))

		var tick_ctx := make_event_context(0.0, Vector3.UP, global_position, 0, tilt_deg)
		var tick_actions := synergy_bus.on_physics_tick(tick_ctx, delta)
		_consume_synergy_actions(tick_actions)

	# Low-speed stuck protection
	if linear_velocity.length() < STUCK_SPEED_THRESHOLD:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_DURATION:
			_stuck_timer = 0.0
			apply_central_impulse(Vector3(0.0, 0.0, -4.5 * mass))
	else:
		_stuck_timer = 0.0

	# Clamp maximum velocity
	var spd := linear_velocity.length()
	if spd > MAX_SPEED:
		linear_velocity = linear_velocity * (MAX_SPEED / spd)

	_saved_velocity_pre_step = linear_velocity


func make_event_context(
	vertical_impact: float = 0.0,
	normal: Vector3 = Vector3.UP,
	pos: Vector3 = Vector3.ZERO,
	chain_depth: int = 0,
	tilt_deg: float = 0.0
) -> PhysicsEventContext:
	var spd := get_pre_step_speed()
	var stacks := synergy_bus.combo_stacks if synergy_bus != null else 0
	return PhysicsEventContext.create(
		spd,
		linear_velocity.x,
		tilt_deg,
		mass,
		vertical_impact,
		normal,
		pos,
		stacks,
		chain_depth
	)


func apply_forward_impulse(impulse_ns: float) -> void:
	if impulse_ns <= 0.0 or is_respawning:
		return
	var delta_v := impulse_ns / maxf(0.1, mass)
	linear_velocity.z -= delta_v
	var spd := linear_velocity.length()
	if spd > MAX_SPEED:
		linear_velocity = linear_velocity * (MAX_SPEED / spd)
	_saved_velocity_pre_step = linear_velocity


func notify_smash_target(target_pos: Vector3, base_speed_loss_ratio: float, chain_depth: int = 0) -> void:
	var loss_mult := synergy_bus.stats.get_stat("smash_speed_loss_mult") if synergy_bus != null else 1.0
	var actual_loss := clampf(base_speed_loss_ratio * loss_mult, 0.0, 0.85)
	var pre_vel := _saved_velocity_pre_step if _saved_velocity_pre_step.length() > linear_velocity.length() else linear_velocity
	linear_velocity = pre_vel * (1.0 - actual_loss)

	target_smashed.emit(target_pos)
	if synergy_bus != null:
		var ctx := make_event_context(0.0, Vector3.BACK, target_pos, chain_depth)
		var actions := synergy_bus.on_smash_target(ctx)
		_consume_synergy_actions(actions)


func notify_wall_or_bumper_bounce(normal: Vector3, contact_pos: Vector3, bonus_forward_impulse: float = 0.0) -> void:
	if bonus_forward_impulse > 0.0:
		var ext_mult := synergy_bus.stats.get_stat("external_boost_mult") if synergy_bus != null else 1.0
		apply_forward_impulse(bonus_forward_impulse * ext_mult)
	if synergy_bus != null:
		var ctx := make_event_context(0.0, normal, contact_pos, 0)
		var actions := synergy_bus.on_wall_or_bumper_bounce(ctx)
		_consume_synergy_actions(actions)


func notify_external_boost(base_forward_impulse: float, origin_pos: Vector3) -> void:
	var ext_mult := synergy_bus.stats.get_stat("external_boost_mult") if synergy_bus != null else 1.0
	apply_forward_impulse(base_forward_impulse * ext_mult)
	if synergy_bus != null:
		var ctx := make_event_context(0.0, Vector3.FORWARD, origin_pos, 0)
		var actions := synergy_bus.on_boost_pad(ctx)
		_consume_synergy_actions(actions)


func _consume_synergy_actions(actions: Dictionary) -> void:
	var fwd_j := float(actions.get("forward_impulse", 0.0))
	if fwd_j > 0.0:
		apply_forward_impulse(fwd_j)
	var waves: Array = actions.get("shockwaves", [])
	var bonus_t := float(actions.get("bonus_time", 0.0))
	if waves.size() > 0 or bonus_t > 0.0:
		synergy_actions_requested.emit(actions)


func _on_body_entered(body: Node) -> void:
	if body == null or is_respawning:
		return
	if body.is_in_group("track_rail") and _rail_bounce_cooldown <= 0.0:
		_rail_bounce_cooldown = 0.12
		var n := Vector3(-signf(global_position.x), 0.0, 0.0)
		notify_wall_or_bumper_bounce(n, global_position, 0.0)
