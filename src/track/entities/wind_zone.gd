class_name WindZone
extends Area3D

const RIBBON_COUNT: int = 12

var zone_size: Vector3 = Vector3(6.0, 3.6, 12.0)
var wind_preset: String = "cross_right"
var wind_dir_local: Vector3 = Vector3.RIGHT
var wind_force_newtons: float = 26.0
var wind_tint: Color = Color(0.36, 0.90, 1.0, 0.58)

var _bodies_in_zone: Array[RigidBody3D] = []
var _initial_scan_done: bool = false
var _visual_phase: float = 0.0
var _flow_root: Node3D = null
var _ribbon_items: Array[Dictionary] = []


func _init() -> void:
	configure_wind(zone_size, wind_preset, -1.0)


func configure_wind(p_size: Vector3, p_preset: String, p_force: float = -1.0) -> void:
	zone_size = Vector3(maxf(1.5, p_size.x), maxf(1.5, p_size.y), maxf(1.5, p_size.z))
	wind_preset = p_preset

	var default_force := 26.0
	match wind_preset:
		"cross_left":
			wind_dir_local = Vector3(-1.0, 0.0, 0.0)
			default_force = 26.0
			wind_tint = Color(0.36, 0.90, 1.0, 0.58)
		"cross_right":
			wind_dir_local = Vector3(1.0, 0.0, 0.0)
			default_force = 26.0
			wind_tint = Color(0.36, 0.90, 1.0, 0.58)
		"tailwind":
			wind_dir_local = Vector3(0.0, 0.0, -1.0)
			default_force = 28.0
			wind_tint = Color(0.24, 0.98, 0.68, 0.60)
		"headwind":
			wind_dir_local = Vector3(0.0, 0.0, 1.0)
			default_force = 21.0
			wind_tint = Color(1.0, 0.58, 0.22, 0.56)
		"updraft":
			wind_dir_local = Vector3(0.0, 0.94, -0.34).normalized()
			default_force = 44.0
			wind_tint = Color(0.24, 1.0, 0.72, 0.64)
		"high_downdraft_left":
			wind_dir_local = Vector3(-0.45, -0.89, 0.0).normalized()
			default_force = 22.0
			wind_tint = Color(1.0, 0.56, 0.24, 0.56)
		"high_downdraft_right":
			wind_dir_local = Vector3(0.45, -0.89, 0.0).normalized()
			default_force = 22.0
			wind_tint = Color(1.0, 0.56, 0.24, 0.56)
		_:
			wind_dir_local = Vector3(1.0, 0.0, 0.0)
			default_force = 26.0
			wind_tint = Color(0.36, 0.90, 1.0, 0.58)

	wind_force_newtons = p_force if p_force > 0.0 else default_force


func contains_local_point(pt_in_parent_space: Vector3, margin: float = 0.25) -> bool:
	var half := zone_size * 0.5 + Vector3.ONE * margin
	var diff := pt_in_parent_space - position
	return (
		absf(diff.x) <= half.x
		and absf(diff.y) <= half.y
		and absf(diff.z) <= half.z
	)


func _ready() -> void:
	add_to_group("wind_zone")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = zone_size
	col.shape = box
	add_child(col)

	_build_wind_visuals()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _build_wind_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var ribbon_mat := MaterialLibrary.make_frosted_acrylic_material(wind_tint)
	var arrow_color := wind_tint.lightened(0.22)
	arrow_color.a = 0.78
	var arrow_mat := MaterialLibrary.make_frosted_acrylic_material(arrow_color)
	var rim_color := Color(wind_tint.r, wind_tint.g, wind_tint.b, 0.28)
	var rim_mat := MaterialLibrary.make_frosted_acrylic_material(rim_color)

	# Subtle base boundary strips on the bottom face of the wind volume so edges read clearly
	for side_x in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_box := BoxMesh.new()
		edge_box.size = Vector3(0.08, 0.05, zone_size.z)
		edge_box.material = rim_mat
		RenderHelper.attach_mesh(edge, edge_box)
		edge.position = Vector3(side_x * (zone_size.x * 0.5 - 0.04), -zone_size.y * 0.5 + 0.03, 0.0)
		add_child(edge)

	# Orient _flow_root so its -Z axis points strictly along wind_dir_local
	_flow_root = Node3D.new()
	_flow_root.name = "WindFlowRoot"
	var up_hint := Vector3.UP if absf(wind_dir_local.dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
	_flow_root.basis = Basis.looking_at(wind_dir_local, up_hint)
	add_child(_flow_root)

	var flow_span := _compute_flow_span(wind_dir_local)
	var cross_w := maxf(1.4, _compute_flow_span(_flow_root.basis.x) * 0.76)
	var cross_h := maxf(1.2, _compute_flow_span(_flow_root.basis.y) * 0.68)
	var ribbon_base_len := clampf(flow_span * 0.26, 1.4, 2.6)

	_ribbon_items.clear()
	for i in range(RIBBON_COUNT):
		var u := (float(i % 4) + 0.5) / 4.0 - 0.5
		@warning_ignore("integer_division")
		var row := i / 4
		var v := (float(row) + 0.5) / 3.0 - 0.5
		var stagger := fmod(float(i) * 0.29 + float(row) * 0.17, 1.0)

		var rib := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(0.055, 0.035, ribbon_base_len)
		rbox.material = ribbon_mat
		RenderHelper.attach_mesh(rib, rbox)
		_flow_root.add_child(rib)

		_ribbon_items.append({
			"node": rib,
			"x": u * cross_w,
			"y": v * cross_h,
			"offset": stagger,
			"span": flow_span,
		})

	# Three crisp 3D chevron arrowheads pointing along wind_dir_local (-Z of _flow_root)
	var chevron_rot := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	for idx in range(3):
		var z_frac := (float(idx) - 1.0) * 0.28 * flow_span
		var chev := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.68, 0.56, 0.10)
		prism.material = arrow_mat
		RenderHelper.attach_mesh(chev, prism)
		chev.transform = Transform3D(chevron_rot, Vector3(0.0, 0.0, z_frac))
		_flow_root.add_child(chev)

	_update_ribbon_transforms()


func _compute_flow_span(dir: Vector3) -> float:
	var n := dir.normalized()
	return absf(n.x) * zone_size.x + absf(n.y) * zone_size.y + absf(n.z) * zone_size.z


func _update_ribbon_transforms() -> void:
	for item in _ribbon_items:
		var node: MeshInstance3D = item["node"]
		if node == null or not is_instance_valid(node):
			continue
		var span := float(item["span"])
		var t := fposmod(_visual_phase + float(item["offset"]), 1.0)
		var z_pos := lerpf(span * 0.44, -span * 0.44, t)
		var envelope := sin(t * PI)
		node.position = Vector3(float(item["x"]), float(item["y"]), z_pos)
		node.scale = Vector3(maxf(0.15, envelope), maxf(0.15, envelope), maxf(0.20, envelope))


func _on_body_entered(body: Node) -> void:
	if body is RigidBody3D:
		var rb := body as RigidBody3D
		if not _bodies_in_zone.has(rb):
			_bodies_in_zone.append(rb)


func _on_body_exited(body: Node) -> void:
	if body is RigidBody3D:
		_bodies_in_zone.erase(body as RigidBody3D)


func _sync_overlapping_rigidbodies() -> void:
	for b in get_overlapping_bodies():
		if b is RigidBody3D:
			var rb := b as RigidBody3D
			if not _bodies_in_zone.has(rb):
				_bodies_in_zone.append(rb)


func _physics_process(delta: float) -> void:
	if not _initial_scan_done:
		_initial_scan_done = true
		_sync_overlapping_rigidbodies()
	elif monitoring:
		_sync_overlapping_rigidbodies()

	var span := maxf(2.0, _compute_flow_span(wind_dir_local))
	var scroll_speed := clampf(wind_force_newtons * 0.42, 7.0, 19.0)
	_visual_phase = fposmod(_visual_phase + (scroll_speed * delta) / span, 1.0)
	if not _ribbon_items.is_empty():
		_update_ribbon_transforms()

	var basis_world := (
		global_transform.basis.orthonormalized()
		if is_inside_tree()
		else transform.basis.orthonormalized()
	)
	var w_world := (basis_world * wind_dir_local).normalized()
	var max_wind_speed := clampf(wind_force_newtons * 0.78, 16.0, 34.0)

	for i in range(_bodies_in_zone.size() - 1, -1, -1):
		var rb := _bodies_in_zone[i]
		if rb == null or not is_instance_valid(rb) or rb.is_queued_for_deletion():
			_bodies_in_zone.remove_at(i)
			continue
		if rb.freeze:
			continue

		if rb is PlayerBall3D:
			_apply_wind_to_ball(rb as PlayerBall3D, w_world)
		else:
			_apply_wind_to_obstacle(rb, w_world, max_wind_speed)


func _apply_wind_to_ball(ball: PlayerBall3D, w_world: Vector3) -> void:
	if ball.is_respawning or ball._is_paused:
		return
	var area_scale := pow(ball.current_radius / StatSheet.BASE_RADIUS, 1.5)
	var f_vec := w_world * (wind_force_newtons * area_scale)
	var t_basis := ball.get_track_basis()
	var up_dir := t_basis.y.normalized()
	var base_up := f_vec.dot(up_dir)
	if base_up > 0.0:
		f_vec += up_dir * (base_up * 0.65)

	if ball.synergy_bus != null:
		var ext_mult := ball.synergy_bus.stats.get_stat("external_boost_mult")
		if ext_mult > 1.001:
			var fwd_dir := -t_basis.z.normalized()
			var fwd_comp := f_vec.dot(fwd_dir)
			var up_comp := f_vec.dot(up_dir)
			if fwd_comp > 0.0:
				f_vec += fwd_dir * (fwd_comp * (ext_mult - 1.0))
			if up_comp > 0.0:
				f_vec += up_dir * (up_comp * (ext_mult - 1.0))

	ball.apply_central_force(f_vec)


func _apply_wind_to_obstacle(rb: RigidBody3D, w_world: Vector3, max_wind_speed: float) -> void:
	var along_v := rb.linear_velocity.dot(w_world)
	var rel_factor := clampf(1.0 - (along_v / max_wind_speed), 0.0, 1.25)

	if rb is AerialBlocker:
		var ab := rb as AerialBlocker
		var area_ab := 1.15 if ab.blocker_type == "soft_balloon" else 0.95
		if ab.is_tethered:
			if ab.blocker_type == "soft_balloon" and wind_force_newtons * area_ab >= 12.0:
				ab.untether()
			else:
				return
		if ab.blocker_type == "soft_balloon":
			var balloon_max_speed := clampf(wind_force_newtons * 0.25, 5.5, 9.0)
			var balloon_rel := clampf(1.0 - (along_v / balloon_max_speed), 0.0, 1.25)
			rb.apply_central_force(w_world * (wind_force_newtons * 0.24 * balloon_rel))
		else:
			rb.apply_central_force(w_world * (wind_force_newtons * area_ab * rel_factor))
		return

	if rb is BouncerSlime:
		var slime := rb as BouncerSlime
		if slime.is_patrolling:
			return
		rb.apply_central_force(w_world * (wind_force_newtons * 1.0 * rel_factor))
		return

	if rb is WoodenPin:
		var pin := rb as WoodenPin
		var f_pin := wind_force_newtons * 0.95 * rel_factor
		if f_pin >= 9.5:
			pin.dislodge()
		var pin_up := (
			pin.global_transform.basis.y.normalized()
			if pin.is_inside_tree()
			else pin.transform.basis.y.normalized()
		)
		pin.apply_force(w_world * f_pin, pin_up * 0.36)
		return

	if rb is CrateObstacle:
		var crate := rb as CrateObstacle
		var area_c := 0.90 if crate.weight_tier == "light" else 1.05
		var f_crate := wind_force_newtons * area_c * rel_factor
		if crate.weight_tier == "light" and f_crate >= 9.5:
			crate.dislodge()
		elif crate.weight_tier == "medium" and f_crate >= 34.0:
			crate.dislodge()
		crate.apply_central_force(w_world * f_crate)
		return

	if rb is ExplosiveBarrel:
		var barrel := rb as ExplosiveBarrel
		var area_b := 0.95
		var f_barrel := wind_force_newtons * area_b * rel_factor
		if barrel.is_detonated and f_barrel >= 8.0:
			barrel.sleeping = false
		barrel.apply_central_force(w_world * f_barrel)
		return

	# ShieldBrute (20kg) and any generic RigidBody3D receive pure Newtonian force indiscriminately
	rb.apply_central_force(w_world * (wind_force_newtons * 1.10 * rel_factor))
