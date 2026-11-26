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
const SURFACE_SUPPORT_GRACE: float = 0.08
const OBSTACLE_BOUNCE_COOLDOWN: float = 0.18
const MIN_OBSTACLE_REBOUND_DV: float = 3.2
const MIN_RAIL_BOUNCE_DV: float = 0.75

var synergy_bus: PhysicsSynergyBus = null
var track_reference: Node3D = null
var current_radius: float = 0.55
var safe_floor_y: float = 0.0
var last_safe_pos: Vector3 = Vector3(0.0, 0.8, -2.0)
var is_respawning: bool = false
var respawn_time_left: float = 0.0

var _slime_zone_count: int = 0
var _stuck_timer: float = 0.0
var _air_time: float = 0.0
var _surface_support_timer: float = 0.0
var _elevated_landing_impact: bool = false
var _peak_downward_speed: float = 0.0
var _rail_bounce_cooldown: float = 0.0
var _obstacle_bounce_cooldown: float = 0.0
var _saved_velocity_pre_step: Vector3 = Vector3.ZERO
var _pending_contact_events: Array[Dictionary] = []
var _last_step_physics_frame: int = -1
var last_external_boost_origin: Vector3 = Vector3(INF, INF, INF)
var _is_paused: bool = false
var _paused_freeze: bool = false
var _paused_linear_vel: Vector3 = Vector3.ZERO
var _paused_angular_vel: Vector3 = Vector3.ZERO
var _paused_pre_step_vel: Vector3 = Vector3.ZERO

var _collision_shape: CollisionShape3D = null
var _sphere_shape: SphereShape3D = null
var _visual_root: Node3D = null
var _core_mesh: MeshInstance3D = null
var _hud_ring_root: Node3D = null
var _left_arrow_group: Node3D = null
var _right_arrow_group: Node3D = null
var _weight_label_3d: Label3D = null


func _ready() -> void:
	add_to_group("player_ball")
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 16
	can_sleep = false

	if physics_material_override == null:
		var mat := PhysicsMaterial.new()
		mat.friction = 0.42
		mat.bounce = 0.25
		physics_material_override = mat

	_build_nodes_if_needed()
	sync_from_stats()


func _process(_delta: float) -> void:
	_update_hud_ring_transform()


func _physics_process(delta: float) -> void:
	var cur_frame := Engine.get_physics_frames()
	if _last_step_physics_frame == cur_frame:
		_flush_pending_contact_events()
		return
	_rail_bounce_cooldown = maxf(0.0, _rail_bounce_cooldown - delta)
	_obstacle_bounce_cooldown = maxf(0.0, _obstacle_bounce_cooldown - delta)
	_surface_support_timer = maxf(0.0, _surface_support_timer - delta)
	_flush_pending_contact_events()
	if not is_respawning and not _is_paused:
		_saved_velocity_pre_step = linear_velocity


func setup(p_bus: PhysicsSynergyBus) -> void:
	synergy_bus = p_bus
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 16
	can_sleep = false
	if physics_material_override == null:
		var mat := PhysicsMaterial.new()
		mat.friction = 0.42
		mat.bounce = 0.25
		physics_material_override = mat
	_build_nodes_if_needed()
	sync_from_stats()


func has_valid_track_reference() -> bool:
	return track_reference != null and is_instance_valid(track_reference)


func _has_valid_track_reference() -> bool:
	return has_valid_track_reference()


func get_track_basis() -> Basis:
	if has_valid_track_reference():
		if track_reference.is_inside_tree():
			return track_reference.global_transform.basis.orthonormalized()
		return track_reference.transform.basis.orthonormalized()
	return Basis.IDENTITY


func _get_track_basis() -> Basis:
	return get_track_basis()


func _to_track_local(world_pos: Vector3) -> Vector3:
	if _has_valid_track_reference():
		if track_reference.is_inside_tree():
			return track_reference.to_local(world_pos)
		return track_reference.transform.affine_inverse() * world_pos
	return world_pos


func _to_track_world(local_pos: Vector3) -> Vector3:
	if _has_valid_track_reference():
		if track_reference.is_inside_tree():
			return track_reference.to_global(local_pos)
		return track_reference.transform * local_pos
	return local_pos


func _get_ball_world_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _set_ball_world_pos(world_pos: Vector3) -> void:
	if is_inside_tree():
		global_position = world_pos
	else:
		position = world_pos


func has_ground_or_sky_support() -> bool:
	var local_pos := _to_track_local(_get_ball_world_pos())
	if (local_pos.y - (safe_floor_y + current_radius)) <= 0.38:
		return true
	if _surface_support_timer > 0.0:
		var up_speed := linear_velocity.dot(_get_track_basis().y)
		if up_speed <= 3.5:
			return true
	return false


func is_airborne() -> bool:
	return not has_ground_or_sky_support()


func _build_nodes_if_needed() -> void:
	if _collision_shape != null:
		return

	var is_headless := DisplayServer.get_name() == "headless"

	_sphere_shape = SphereShape3D.new()
	_sphere_shape.radius = current_radius
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = _sphere_shape
	add_child(_collision_shape)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_core_mesh = MeshInstance3D.new()
	_core_mesh.name = "CoreMesh"
	_visual_root.add_child(_core_mesh)

	if not is_headless:
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.10
		sm.radial_segments = 32
		sm.rings = 20
		sm.material = MaterialLibrary.make_tungsten_ball_material()
		RenderHelper.attach_mesh(_core_mesh, sm)

		var groove_mat := MaterialLibrary.make_silicone_soft_material(Color(0.96, 0.78, 0.46))
		for idx in range(2):
			var band := MeshInstance3D.new()
			var band_torus := TorusMesh.new()
			band_torus.inner_radius = 0.525
			band_torus.outer_radius = 0.562
			band_torus.rings = 28
			band_torus.ring_segments = 12
			band_torus.material = groove_mat
			RenderHelper.attach_mesh(band, band_torus)
			if idx == 1:
				band.rotation_degrees.z = 90.0
			_visual_root.add_child(band)

	_hud_ring_root = Node3D.new()
	_hud_ring_root.name = "HudRingRoot"
	add_child(_hud_ring_root)

	_left_arrow_group = Node3D.new()
	_left_arrow_group.name = "LeftArrowGroup"
	_left_arrow_group.visible = false
	_hud_ring_root.add_child(_left_arrow_group)

	_right_arrow_group = Node3D.new()
	_right_arrow_group.name = "RightArrowGroup"
	_right_arrow_group.visible = false
	_hud_ring_root.add_child(_right_arrow_group)

	if not is_headless:
		_build_hud_ring_visuals()

	set_meta("weight_label", "%0.1fkg" % mass)


func _build_hud_ring_visuals() -> void:
	var halo_inst := MeshInstance3D.new()
	halo_inst.name = "EquatorialHalo"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.64
	torus.outer_radius = 0.675
	torus.rings = 28
	torus.ring_segments = 12
	torus.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.98, 0.94, 0.86, 0.22))
	RenderHelper.attach_mesh(halo_inst, torus)
	halo_inst.position = Vector3(0.0, 0.05, 0.0)
	_hud_ring_root.add_child(halo_inst)

	_weight_label_3d = Label3D.new()
	_weight_label_3d.name = "BallWeightLabel"
	var font := load(MaterialLibrary.BUNDLED_FONT_PATH) as Font
	if font != null:
		_weight_label_3d.font = font
	_weight_label_3d.text = "%0.1fkg" % mass
	_weight_label_3d.font_size = 44
	_weight_label_3d.outline_size = 3
	_weight_label_3d.pixel_size = 0.0036
	_weight_label_3d.modulate = Color(0.99, 0.96, 0.89, 0.88)
	_weight_label_3d.outline_modulate = Color(0.32, 0.23, 0.16, 0.45)
	_weight_label_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_label_3d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weight_label_3d.double_sided = false
	_weight_label_3d.shaded = false
	_weight_label_3d.render_priority = 4
	_weight_label_3d.position = Vector3(0.0, 0.82, 0.14)
	_weight_label_3d.rotation_degrees = Vector3(-27.0, 0.0, 0.0)
	_hud_ring_root.add_child(_weight_label_3d)

	var mint_mat := MaterialLibrary.make_silicone_soft_material(Color(0.46, 0.86, 0.72))
	var gold_mat := MaterialLibrary.make_silicone_soft_material(Color(0.98, 0.82, 0.42))
	var puff_mat := MaterialLibrary.make_silicone_soft_material(Color(0.99, 0.97, 0.93))

	_populate_thrust_side_visuals(_left_arrow_group, -1.0, mint_mat, gold_mat, puff_mat)
	_populate_thrust_side_visuals(_right_arrow_group, 1.0, mint_mat, gold_mat, puff_mat)


func _populate_thrust_side_visuals(
	group: Node3D,
	dir_sign: float,
	mint_mat: StandardMaterial3D,
	gold_mat: StandardMaterial3D,
	puff_mat: StandardMaterial3D
) -> void:
	var point_rot := Basis(Vector3.BACK, deg_to_rad(-90.0 * dir_sign))

	# Rounded soft clay cone-droplet pointer instead of sharp PrismMesh
	var wedge_inst := MeshInstance3D.new()
	wedge_inst.name = "ArrowWedge"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.035
	cone.bottom_radius = 0.19
	cone.height = 0.36
	cone.radial_segments = 16
	cone.material = mint_mat
	RenderHelper.attach_mesh(wedge_inst, cone)
	wedge_inst.transform = Transform3D(point_rot, Vector3(dir_sign * 0.96, 0.14, 0.0))
	group.add_child(wedge_inst)

	var stem_inst := MeshInstance3D.new()
	stem_inst.name = "ArrowStem"
	var stem_cap := CapsuleMesh.new()
	stem_cap.radius = 0.075
	stem_cap.height = 0.26
	stem_cap.radial_segments = 12
	stem_cap.material = gold_mat
	RenderHelper.attach_mesh(stem_inst, stem_cap)
	stem_inst.transform = Transform3D(point_rot, Vector3(dir_sign * 0.74, 0.14, 0.0))
	group.add_child(stem_inst)

	# Soft fluffy cotton cloud puffs instead of sharp rectangular jet boxes
	var puff_offsets: Array[Vector3] = [
		Vector3(-dir_sign * 0.82, 0.14, 0.0),
		Vector3(-dir_sign * 0.98, 0.16, -0.17),
		Vector3(-dir_sign * 0.94, 0.12, 0.17),
	]
	var puff_radii: Array[float] = [0.115, 0.088, 0.082]
	for idx in range(3):
		var puff_inst := MeshInstance3D.new()
		puff_inst.name = "JetPuff%d" % idx
		puff_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var puff_sphere := SphereMesh.new()
		puff_sphere.radius = puff_radii[idx]
		puff_sphere.height = puff_radii[idx] * 1.85
		puff_sphere.radial_segments = 14
		puff_sphere.rings = 8
		puff_sphere.material = puff_mat
		RenderHelper.attach_mesh(puff_inst, puff_sphere)
		puff_inst.position = puff_offsets[idx]
		group.add_child(puff_inst)


func _update_hud_ring_transform() -> void:
	if _hud_ring_root == null:
		return
	var scale_factor := current_radius / StatSheet.BASE_RADIUS
	var target_basis := _get_track_basis().scaled(Vector3.ONE * scale_factor)
	if is_inside_tree():
		_hud_ring_root.global_transform = Transform3D(target_basis, global_position)
	else:
		_hud_ring_root.transform = Transform3D(target_basis, Vector3.ZERO)


func _update_hud_ring_indicators(thrust_axis: float) -> void:
	_update_hud_ring_transform()
	if _hud_ring_root == null:
		return
	_hud_ring_root.visible = not is_respawning
	if is_respawning or absf(thrust_axis) <= 0.05:
		_left_arrow_group.visible = false
		_right_arrow_group.visible = false
	elif thrust_axis < -0.05:
		_left_arrow_group.visible = true
		_right_arrow_group.visible = false
	else:
		_left_arrow_group.visible = false
		_right_arrow_group.visible = true


func clear_thrust_indicators() -> void:
	_update_hud_ring_indicators(0.0)


func set_paused(paused: bool) -> void:
	if paused:
		if _is_paused:
			return
		_is_paused = true
		_paused_freeze = freeze
		_paused_linear_vel = linear_velocity
		_paused_angular_vel = angular_velocity
		_paused_pre_step_vel = _saved_velocity_pre_step
		clear_thrust_indicators()
		freeze = true
	else:
		if not _is_paused:
			return
		_is_paused = false
		if is_respawning:
			freeze = true
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_saved_velocity_pre_step = Vector3.ZERO
		else:
			freeze = _paused_freeze
			if not _paused_freeze:
				linear_velocity = _paused_linear_vel
				angular_velocity = _paused_angular_vel
				_saved_velocity_pre_step = _paused_pre_step_vel


func sync_from_stats() -> void:
	if synergy_bus != null:
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

	var weight_txt := "%0.1fkg" % mass
	set_meta("weight_label", weight_txt)
	if _weight_label_3d != null:
		_weight_label_3d.text = weight_txt
	_update_hud_ring_transform()


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
	_is_paused = false
	is_respawning = false
	respawn_time_left = 0.0
	_slime_zone_count = 0
	_stuck_timer = 0.0
	_air_time = 0.0
	_surface_support_timer = 0.0
	_elevated_landing_impact = false
	_peak_downward_speed = 0.0
	_rail_bounce_cooldown = 0.0
	_obstacle_bounce_cooldown = 0.0
	_pending_contact_events.clear()
	_last_step_physics_frame = -1
	last_external_boost_origin = Vector3(INF, INF, INF)
	freeze = false
	_set_ball_world_pos(start_pos)
	sync_from_stats()
	var start_local := _to_track_local(start_pos)
	safe_floor_y = start_local.y - current_radius
	last_safe_pos = start_local
	var fwd_dir := -_get_track_basis().z
	linear_velocity = fwd_dir * 4.5
	angular_velocity = Vector3.ZERO
	_saved_velocity_pre_step = linear_velocity
	_update_hud_ring_indicators(0.0)


func get_pre_step_speed() -> float:
	return maxf(linear_velocity.length(), _saved_velocity_pre_step.length())


func get_current_momentum() -> float:
	return mass * get_pre_step_speed()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_respawning or _is_paused:
		return
	var contact_count := state.get_contact_count()
	if contact_count <= 0:
		return

	var ball_origin := state.transform.origin
	var total_contact_impulse := Vector3.ZERO
	var by_collider: Dictionary = {}

	for i in range(contact_count):
		var imp := state.get_contact_impulse(i)
		total_contact_impulse += imp

		var col_obj := state.get_contact_collider_object(i)
		if col_obj == null or not is_instance_valid(col_obj) or not (col_obj is Node):
			continue
		var col_node := col_obj as Node
		var c_pos := state.get_contact_local_position(i)
		var c_norm := state.get_contact_local_normal(i)
		var to_center := ball_origin - c_pos
		if to_center.length_squared() > 0.0001 and c_norm.dot(to_center) < 0.0:
			c_norm = -c_norm
		elif imp.length_squared() > 0.0001 and c_norm.dot(imp) < 0.0:
			c_norm = -c_norm

		var cid := col_node.get_instance_id()
		if not by_collider.has(cid):
			by_collider[cid] = {
				"collider": col_node,
				"pos_sum": c_pos,
				"norm_sum": c_norm,
				"impulse": imp,
				"count": 1,
			}
		else:
			var entry: Dictionary = by_collider[cid]
			entry["pos_sum"] = (entry["pos_sum"] as Vector3) + c_pos
			entry["norm_sum"] = (entry["norm_sum"] as Vector3) + c_norm
			entry["impulse"] = (entry["impulse"] as Vector3) + imp
			entry["count"] = int(entry["count"]) + 1

	var eff_mass := maxf(0.1, mass)
	var v_post_raw := state.linear_velocity
	var v_pre := _saved_velocity_pre_step
	if total_contact_impulse.length_squared() > 0.0001:
		v_pre = v_post_raw - (total_contact_impulse / eff_mass) - state.total_gravity * state.step
	elif v_pre.length_squared() <= 0.0001:
		v_pre = v_post_raw

	var track_up := get_track_basis().y.normalized()
	var hit_movable_obstacle := false
	var hit_undetonated_barrel := false

	for cid in by_collider.keys():
		var entry: Dictionary = by_collider[cid]
		var col_node: Node = entry["collider"]
		if col_node == null or not is_instance_valid(col_node):
			continue
		var cnt := float(maxi(1, int(entry["count"])))
		var contact_pos: Vector3 = (entry["pos_sum"] as Vector3) / cnt
		var norm_raw: Vector3 = entry["norm_sum"] as Vector3
		var contact_normal := norm_raw.normalized() if norm_raw.length_squared() > 0.0001 else Vector3.UP
		var col_impulse: Vector3 = entry["impulse"]
		var impulse_mag := col_impulse.length()
		if impulse_mag <= 0.001:
			impulse_mag = eff_mass * (v_post_raw - v_pre).length()

		if (
			col_node is StaticBody3D
			and not col_node.is_in_group("track_rail")
			and not col_node.is_in_group("pinball_bumper")
			and contact_normal.dot(track_up) >= 0.62
		):
			_surface_support_timer = SURFACE_SUPPORT_GRACE
			var pre_up_vel := v_pre.dot(track_up)
			if pre_up_vel < -2.2:
				_elevated_landing_impact = true
				_peak_downward_speed = maxf(_peak_downward_speed, -pre_up_vel)

		if col_node.is_in_group("pinball_bumper") and col_node.has_method("trigger_bumper_bounce"):
			_pending_contact_events.append({
				"kind": "pinball_bumper",
				"collider": col_node,
				"normal": contact_normal,
				"pos": contact_pos,
				"v_pre": v_pre,
			})
		elif col_node.is_in_group("track_rail"):
			var rail_dv := maxf(
				col_impulse.dot(contact_normal) / eff_mass,
				(v_post_raw - v_pre).dot(contact_normal)
			)
			if rail_dv >= MIN_RAIL_BOUNCE_DV:
				_pending_contact_events.append({
					"kind": "track_rail",
					"collider": col_node,
					"normal": contact_normal,
					"pos": contact_pos,
					"v_pre": v_pre,
				})
		elif col_node is ExplosiveBarrel:
			var barrel := col_node as ExplosiveBarrel
			if not barrel.is_detonated:
				hit_undetonated_barrel = true
				_pending_contact_events.append({
					"kind": "explosive_barrel",
					"collider": barrel,
					"normal": contact_normal,
					"pos": contact_pos,
					"v_pre": v_pre,
				})
			else:
				hit_movable_obstacle = true
		elif col_node.has_method("on_ball_physical_impact"):
			hit_movable_obstacle = true
			var dv_from_col := col_impulse.dot(contact_normal) / eff_mass
			var dv_from_vel := (v_post_raw - v_pre).dot(contact_normal)
			var normal_rebound_dv := maxf(dv_from_col, dv_from_vel)
			var v_post_n := v_post_raw.dot(contact_normal)
			var obs_bounce := 0.0
			if col_node is RigidBody3D and (col_node as RigidBody3D).physics_material_override != null:
				obs_bounce = (col_node as RigidBody3D).physics_material_override.bounce
			var did_rebound := (v_post_n >= -0.25) or (obs_bounce >= 0.75)
			_pending_contact_events.append({
				"kind": "movable_obstacle",
				"collider": col_node,
				"normal": contact_normal,
				"pos": contact_pos,
				"impulse_mag": impulse_mag,
				"normal_rebound_dv": normal_rebound_dv if did_rebound else 0.0,
				"v_pre": v_pre,
			})

	if hit_movable_obstacle and not hit_undetonated_barrel and synergy_bus != null:
		var loss_mult := synergy_bus.stats.get_stat("smash_speed_loss_mult")
		if loss_mult < 0.999:
			var fwd_dir := -get_track_basis().z.normalized()
			var dv_fwd := v_pre.dot(fwd_dir) - state.linear_velocity.dot(fwd_dir)
			if dv_fwd > 0.2:
				var restore_ratio := 1.0 - clampf(loss_mult, 0.0, 1.0)
				var restored_vel := state.linear_velocity + fwd_dir * (dv_fwd * restore_ratio)
				var max_spd := v_pre.length()
				if max_spd > 0.001 and restored_vel.length() > max_spd:
					restored_vel = restored_vel.normalized() * max_spd
				state.linear_velocity = restored_vel


func _flush_pending_contact_events() -> void:
	if _pending_contact_events.is_empty():
		return
	var events := _pending_contact_events.duplicate()
	_pending_contact_events.clear()

	if is_respawning or _is_paused:
		return

	for ev in events:
		var raw_col: Variant = ev.get("collider", null)
		if raw_col == null or not is_instance_valid(raw_col):
			continue
		var collider := raw_col as Node
		if collider == null or collider.is_queued_for_deletion():
			continue

		var kind := str(ev.get("kind", ""))
		var contact_normal: Vector3 = ev.get("normal", Vector3.UP)
		var contact_pos: Vector3 = ev.get("pos", _get_ball_world_pos())
		var v_pre: Vector3 = ev.get("v_pre", _saved_velocity_pre_step)

		match kind:
			"track_rail":
				if _rail_bounce_cooldown <= 0.0:
					_rail_bounce_cooldown = 0.12
					if v_pre.length() > _saved_velocity_pre_step.length():
						_saved_velocity_pre_step = v_pre
					notify_wall_or_bumper_bounce(contact_normal, contact_pos, 0.0)
			"pinball_bumper":
				if collider.has_method("trigger_bumper_bounce"):
					if v_pre.length() > _saved_velocity_pre_step.length():
						_saved_velocity_pre_step = v_pre
					collider.call("trigger_bumper_bounce", self, contact_normal)
			"explosive_barrel":
				if collider is ExplosiveBarrel:
					var barrel := collider as ExplosiveBarrel
					if not barrel.is_detonated:
						if v_pre.length() > _saved_velocity_pre_step.length():
							_saved_velocity_pre_step = v_pre
						barrel.on_ball_contact(self)
			"movable_obstacle":
				var impulse_mag := float(ev.get("impulse_mag", 0.0))
				var normal_rebound_dv := float(ev.get("normal_rebound_dv", 0.0))
				if collider.has_method("on_ball_physical_impact"):
					if v_pre.length() > _saved_velocity_pre_step.length():
						_saved_velocity_pre_step = v_pre
					var yielded_smash := bool(collider.call("on_ball_physical_impact", impulse_mag))
					if yielded_smash:
						if v_pre.length() > _saved_velocity_pre_step.length():
							_saved_velocity_pre_step = v_pre
						notify_obstacle_impact(contact_pos, 0)
				if normal_rebound_dv >= MIN_OBSTACLE_REBOUND_DV and _obstacle_bounce_cooldown <= 0.0:
					_obstacle_bounce_cooldown = OBSTACLE_BOUNCE_COOLDOWN
					if v_pre.length() > _saved_velocity_pre_step.length():
						_saved_velocity_pre_step = v_pre
					notify_wall_or_bumper_bounce(contact_normal, contact_pos, 0.0)


func step_ball(delta: float, thrust_axis: float, lateral_accel: float = 0.0) -> void:
	_last_step_physics_frame = Engine.get_physics_frames()
	_rail_bounce_cooldown = maxf(0.0, _rail_bounce_cooldown - delta)
	_obstacle_bounce_cooldown = maxf(0.0, _obstacle_bounce_cooldown - delta)
	_flush_pending_contact_events()
	var track_basis := _get_track_basis()

	if is_respawning:
		_pending_contact_events.clear()
		respawn_time_left -= delta
		if respawn_time_left <= 0.0:
			is_respawning = false
			freeze = false
			var respawn_local := last_safe_pos + Vector3(0.0, 1.2, 0.0)
			_set_ball_world_pos(_to_track_world(respawn_local))
			linear_velocity = (-track_basis.z) * 6.5
			angular_velocity = Vector3.ZERO
			_saved_velocity_pre_step = linear_velocity
			respawn_state_changed.emit(false)
		_update_hud_ring_indicators(0.0)
		return

	var world_pos := _get_ball_world_pos()
	var local_pos := _to_track_local(world_pos)

	# Check fall below track abyss in track-local coordinates
	if local_pos.y < safe_floor_y - FALL_Y_OFFSET:
		is_respawning = true
		_surface_support_timer = 0.0
		_elevated_landing_impact = false
		respawn_time_left = RESPAWN_DURATION
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
		_update_hud_ring_indicators(0.0)
		respawn_state_changed.emit(true)
		return

	# Update safe respawn anchor when comfortably near floor center in track-local space
	if local_pos.y >= safe_floor_y - 0.5 and local_pos.y <= safe_floor_y + current_radius + 0.6:
		if absf(local_pos.x) <= 3.0:
			last_safe_pos = Vector3(0.0, safe_floor_y + current_radius + 0.2, local_pos.z)

	# Airborne tracking & landing detection in track-local space
	var currently_supported := has_ground_or_sky_support()
	var landed_now := currently_supported or _elevated_landing_impact
	_elevated_landing_impact = false
	_surface_support_timer = maxf(0.0, _surface_support_timer - delta)
	if not landed_now:
		_air_time += delta
		var down_speed := -linear_velocity.dot(track_basis.y)
		if down_speed > _peak_downward_speed:
			_peak_downward_speed = down_speed
		if synergy_bus != null:
			gravity_scale = synergy_bus.stats.get_stat("air_gravity_scale")
	else:
		gravity_scale = 1.0
		if _air_time >= AIRBORNE_MIN_TIME and _peak_downward_speed > 2.2:
			var land_ctx := make_event_context(_peak_downward_speed, track_basis.y, world_pos, 0, thrust_axis)
			if synergy_bus != null:
				var land_actions := synergy_bus.on_land(land_ctx)
				_consume_synergy_actions(land_actions)
		_air_time = 0.0
		_peak_downward_speed = 0.0

	# Hold-to-thrust lateral force & instant-release gentle lateral stop damping
	if absf(lateral_accel) > 0.0001:
		apply_central_force(track_basis.x * (lateral_accel * mass))
	elif absf(thrust_axis) < 0.05 and currently_supported:
		var lat_v := linear_velocity.dot(track_basis.x)
		if absf(lat_v) > 0.001:
			apply_central_force(-track_basis.x * (lat_v * 2.2 * mass))

	# Forward slope rolling compensation (sloped track) or legacy extra forward drive (flat world)
	var drive_mult := synergy_bus.stats.get_stat("forward_drive_mult") if synergy_bus != null else 1.0
	if _has_valid_track_reference():
		apply_central_force((-track_basis.z) * (3.2 * drive_mult * mass))
	elif synergy_bus != null and absf(drive_mult - 1.0) > 0.01:
		var extra_accel := (drive_mult - 1.0) * 4.2
		apply_central_force(Vector3(0.0, 0.0, -extra_accel * mass))

	if synergy_bus != null:
		var tick_ctx := make_event_context(0.0, track_basis.y, world_pos, 0, thrust_axis)
		var tick_actions := synergy_bus.on_physics_tick(tick_ctx, delta)
		_consume_synergy_actions(tick_actions)

	# Low-speed stuck protection
	if linear_velocity.length() < STUCK_SPEED_THRESHOLD:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_DURATION:
			_stuck_timer = 0.0
			apply_central_impulse((-track_basis.z) * (4.5 * mass))
	else:
		_stuck_timer = 0.0

	# Clamp maximum velocity
	var spd := linear_velocity.length()
	if spd > MAX_SPEED:
		linear_velocity = linear_velocity * (MAX_SPEED / spd)

	_saved_velocity_pre_step = linear_velocity
	_update_hud_ring_indicators(thrust_axis)


func make_event_context(
	vertical_impact: float = 0.0,
	normal: Vector3 = Vector3.UP,
	pos: Vector3 = Vector3.ZERO,
	chain_depth: int = 0,
	tilt_deg: float = 0.0
) -> PhysicsEventContext:
	var spd := get_pre_step_speed()
	var stacks := synergy_bus.combo_stacks if synergy_bus != null else 0
	var lat_speed := linear_velocity.dot(_get_track_basis().x)
	return PhysicsEventContext.create(
		spd,
		lat_speed,
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
	linear_velocity += (-_get_track_basis().z) * delta_v
	var spd := linear_velocity.length()
	if spd > MAX_SPEED:
		linear_velocity = linear_velocity * (MAX_SPEED / spd)
	_saved_velocity_pre_step = linear_velocity


func notify_obstacle_impact(target_pos: Vector3, chain_depth: int = 0) -> void:
	target_smashed.emit(target_pos)
	if synergy_bus != null:
		var ctx := make_event_context(0.0, _get_track_basis().z, target_pos, chain_depth)
		var actions := synergy_bus.on_smash_target(ctx)
		_consume_synergy_actions(actions)


func notify_smash_target(target_pos: Vector3, _base_speed_loss_ratio: float = 0.0, chain_depth: int = 0) -> void:
	notify_obstacle_impact(target_pos, chain_depth)


func notify_wall_or_bumper_bounce(normal: Vector3, contact_pos: Vector3, bonus_forward_impulse: float = 0.0) -> void:
	if bonus_forward_impulse > 0.0:
		var ext_mult := synergy_bus.stats.get_stat("external_boost_mult") if synergy_bus != null else 1.0
		apply_forward_impulse(bonus_forward_impulse * ext_mult)
	if synergy_bus != null:
		var ctx := make_event_context(0.0, normal, contact_pos, 0)
		var actions := synergy_bus.on_wall_or_bumper_bounce(ctx)
		_consume_synergy_actions(actions)


func notify_external_boost(base_forward_impulse: float, origin_pos: Vector3) -> void:
	last_external_boost_origin = origin_pos
	var ext_mult := synergy_bus.stats.get_stat("external_boost_mult") if synergy_bus != null else 1.0
	apply_forward_impulse(base_forward_impulse * ext_mult)
	if synergy_bus != null:
		var ctx := make_event_context(0.0, -_get_track_basis().z, origin_pos, 0)
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
		var world_pos := _get_ball_world_pos()
		var local_x := _to_track_local(world_pos).x
		var n := _get_track_basis().x * (-signf(local_x))
		notify_wall_or_bumper_bounce(n, world_pos, 0.0)
