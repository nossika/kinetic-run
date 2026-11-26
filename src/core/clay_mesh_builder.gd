class_name ClayMeshBuilder
extends RefCounted

static var _mesh_cache: Dictionary = {}
static var _winding_sign: float = 0.0
static var _eye_dark_mat: StandardMaterial3D = null
static var _eye_shine_mat: StandardMaterial3D = null
static var _blush_mat: StandardMaterial3D = null


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func assign_mesh(mesh_inst: MeshInstance3D, mesh_res: Mesh, mat: Material = null) -> void:
	if mesh_inst == null or _is_headless():
		return
	if mat != null:
		mesh_inst.material_override = mat
	if mesh_res != null:
		RenderHelper.attach_mesh(mesh_inst, mesh_res)


static func _get_front_winding_sign() -> float:
	if _winding_sign == 0.0:
		var bm := BoxMesh.new()
		var arr := bm.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var s := signf((v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]]).dot(n[idx[0]]))
		_winding_sign = s if s != 0.0 else -1.0
	return _winding_sign


static func _q(val: float) -> int:
	return int(round(val * 200.0))


static func _append_oriented_tri(
	indices: PackedInt32Array,
	verts: PackedVector3Array,
	norms: PackedVector3Array,
	i0: int,
	i1: int,
	i2: int,
	wind_sign: float
) -> void:
	var cross := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
	var n_avg := norms[i0] + norms[i1] + norms[i2]
	if cross.dot(n_avg) * wind_sign < 0.0:
		indices.append(i0)
		indices.append(i2)
		indices.append(i1)
	else:
		indices.append(i0)
		indices.append(i1)
		indices.append(i2)


static func make_rounded_box(
	size: Vector3,
	bevel_radius: float = 0.14,
	bevel_segments: int = 3,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var sx := maxf(0.02, size.x)
	var sy := maxf(0.02, size.y)
	var sz := maxf(0.02, size.z)
	var segs := clampi(bevel_segments, 1, 6)
	var max_r := minf(sx, minf(sy, sz)) * 0.46
	var r := clampf(bevel_radius, 0.004, max_r)

	var key := "rbox_%d_%d_%d_%d_%d" % [_q(sx), _q(sy), _q(sz), _q(r), segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var inner := Vector3(
		maxf(0.0, sx * 0.5 - r),
		maxf(0.0, sy * 0.5 - r),
		maxf(0.0, sz * 0.5 - r)
	)
	var m := 2 * segs + 1
	var d_lut: Array[float] = []
	var s_lut: Array[float] = []
	for k in range(m + 1):
		if k <= segs:
			var theta := -PI * 0.5 + (float(k) / float(segs)) * (PI * 0.5)
			d_lut.append(sin(theta))
			s_lut.append(-1.0)
		else:
			var theta := (float(k - (segs + 1)) / float(segs)) * (PI * 0.5)
			d_lut.append(sin(theta))
			s_lut.append(1.0)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()

	# 6 faces packed into 3x2 UV cells matching Godot's BoxMesh UV layout
	var face_defs: Array[Dictionary] = [
		{"axis": 2, "fixed": m, "u_ax": 0, "v_ax": 1, "u_flip": false, "v_flip": true, "cell": Vector2(0, 0)},
		{"axis": 2, "fixed": 0, "u_ax": 0, "v_ax": 1, "u_flip": true, "v_flip": true, "cell": Vector2(1, 0)},
		{"axis": 0, "fixed": m, "u_ax": 2, "v_ax": 1, "u_flip": true, "v_flip": true, "cell": Vector2(2, 0)},
		{"axis": 0, "fixed": 0, "u_ax": 2, "v_ax": 1, "u_flip": false, "v_flip": true, "cell": Vector2(0, 1)},
		{"axis": 1, "fixed": m, "u_ax": 0, "v_ax": 2, "u_flip": false, "v_flip": false, "cell": Vector2(1, 1)},
		{"axis": 1, "fixed": 0, "u_ax": 0, "v_ax": 2, "u_flip": false, "v_flip": true, "cell": Vector2(2, 1)},
	]
	var half_arr := [sx * 0.5, sy * 0.5, sz * 0.5]

	for f_idx in range(face_defs.size()):
		var fd: Dictionary = face_defs[f_idx]
		var axis: int = fd["axis"]
		var fixed_k: int = fd["fixed"]
		var u_ax: int = fd["u_ax"]
		var v_ax: int = fd["v_ax"]
		var u_flip: bool = fd["u_flip"]
		var v_flip: bool = fd["v_flip"]
		var cell: Vector2 = fd["cell"]
		var base_v := verts.size()

		for iv in range(m + 1):
			for iu in range(m + 1):
				var idx3 := [0, 0, 0]
				idx3[axis] = fixed_k
				idx3[u_ax] = iu
				idx3[v_ax] = iv

				var d_vec := Vector3(d_lut[idx3[0]], d_lut[idx3[1]], d_lut[idx3[2]])
				var n_vec := d_vec.normalized()
				var c_vec := Vector3(
					s_lut[idx3[0]] * inner.x,
					s_lut[idx3[1]] * inner.y,
					s_lut[idx3[2]] * inner.z
				)
				var pos := c_vec + n_vec * r
				verts.append(pos)
				norms.append(n_vec)

				var pos_arr := [pos.x, pos.y, pos.z]
				var u01 := clampf(pos_arr[u_ax] / (2.0 * half_arr[u_ax]) + 0.5, 0.0, 1.0)
				var v01 := clampf(pos_arr[v_ax] / (2.0 * half_arr[v_ax]) + 0.5, 0.0, 1.0)
				if u_flip:
					u01 = 1.0 - u01
				if v_flip:
					v01 = 1.0 - v01
				uvs.append(Vector2((cell.x + u01) / 3.0, (cell.y + v01) / 2.0))

		var stride := m + 1
		for iv in range(m):
			for iu in range(m):
				var a := base_v + iv * stride + iu
				var b := a + 1
				var c := a + stride
				var d := c + 1
				_append_oriented_tri(indices, verts, norms, a, b, d, wind_sign)
				_append_oriented_tri(indices, verts, norms, a, d, c, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func make_chamfered_cylinder(
	top_radius: float,
	bottom_radius: float,
	height: float,
	bevel: float = 0.08,
	radial_segments: int = 24,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var rt := maxf(0.02, top_radius)
	var rb := maxf(0.02, bottom_radius)
	var h := maxf(0.02, height)
	var r_segs := clampi(radial_segments, 8, 48)
	var bev := clampf(bevel, 0.004, minf(minf(rt, rb) * 0.48, h * 0.45))

	var key := "ccyl_%d_%d_%d_%d_%d" % [_q(rt), _q(rb), _q(h), _q(bev), r_segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var half_h := h * 0.5
	var b_steps := 3
	var ring_r: Array[float] = [0.0]
	var ring_y: Array[float] = [half_h]
	var ring_nr: Array[float] = [0.0]
	var ring_ny: Array[float] = [1.0]
	var ring_v: Array[float] = [0.75]

	for s in range(b_steps + 1):
		var frac := float(s) / float(b_steps)
		var ang := frac * (PI * 0.5)
		ring_r.append((rt - bev) + sin(ang) * bev)
		ring_y.append((half_h - bev) + cos(ang) * bev)
		ring_nr.append(sin(ang))
		ring_ny.append(cos(ang))
		ring_v.append(lerpf(0.02, 0.10, frac))

	for s in range(b_steps + 1):
		var frac := float(s) / float(b_steps)
		var ang := frac * (PI * 0.5)
		ring_r.append((rb - bev) + cos(ang) * bev)
		ring_y.append(-(half_h - bev) - sin(ang) * bev)
		ring_nr.append(cos(ang))
		ring_ny.append(-sin(ang))
		ring_v.append(lerpf(0.40, 0.48, frac))

	ring_r.append(0.0)
	ring_y.append(-half_h)
	ring_nr.append(0.0)
	ring_ny.append(-1.0)
	ring_v.append(0.75)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()
	var ring_count := ring_r.size()
	var cols := r_segs + 1

	for ri in range(ring_count):
		var rr := ring_r[ri]
		var yy := ring_y[ri]
		var nr := ring_nr[ri]
		var ny := ring_ny[ri]
		var vv := ring_v[ri]
		var is_cap := (ri == 0 or ri == ring_count - 1)
		for ci in range(cols):
			var u := float(ci) / float(r_segs)
			var phi := u * TAU
			var cs := cos(phi)
			var sn := sin(phi)
			verts.append(Vector3(cs * rr, yy, sn * rr))
			norms.append(Vector3(cs * nr, ny, sn * nr).normalized())
			if is_cap:
				uvs.append(Vector2(0.5, 0.75))
			else:
				uvs.append(Vector2(u, vv))

	for ri in range(ring_count - 1):
		for ci in range(r_segs):
			var a := ri * cols + ci
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if ri == 0:
				_append_oriented_tri(indices, verts, norms, a, c, d, wind_sign)
			elif ri == ring_count - 2:
				_append_oriented_tri(indices, verts, norms, a, b, c, wind_sign)
			else:
				_append_oriented_tri(indices, verts, norms, a, b, d, wind_sign)
				_append_oriented_tri(indices, verts, norms, a, d, c, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func make_pebble_pad(
	size_xz: Vector2,
	height: float = 0.10,
	radial_segments: int = 24,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var hx := maxf(0.1, size_xz.x * 0.5)
	var hz := maxf(0.1, size_xz.y * 0.5)
	var h := maxf(0.02, height)
	var r_segs := clampi(radial_segments, 12, 48)
	var key := "pebble_%d_%d_%d_%d" % [_q(hx), _q(hz), _q(h), r_segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var rings := 5
	var half_y := h * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()
	var cols := r_segs + 1

	var total_rings := rings + 2
	for ri in range(total_rings):
		for ci in range(cols):
			var u := float(ci) / float(r_segs)
			var phi := u * TAU
			var cs := cos(phi)
			var sn := sin(phi)
			var sx := signf(cs) * pow(absf(cs), 0.78)
			var sz := signf(sn) * pow(absf(sn), 0.78)

			var rad_t := 0.0
			var yy := half_y
			var ny := 1.0
			var nr := 0.0
			if ri <= rings:
				var frac := float(ri) / float(rings)
				var ang := frac * (PI * 0.5)
				rad_t = sin(ang)
				yy = -half_y + cos(ang) * h
				ny = cos(ang)
				nr = sin(ang) * 0.65
			else:
				rad_t = 0.0
				yy = -half_y
				ny = -1.0
				nr = 0.0

			var px := sx * hx * rad_t
			var pz := sz * hz * rad_t
			verts.append(Vector3(px, yy, pz))
			norms.append(Vector3(cs * nr, ny, sn * nr).normalized())
			uvs.append(Vector2(px / (2.0 * hx) + 0.5, pz / (2.0 * hz) + 0.5))

	for ri in range(total_rings - 1):
		for ci in range(r_segs):
			var a := ri * cols + ci
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if ri == 0:
				_append_oriented_tri(indices, verts, norms, a, c, d, wind_sign)
			elif ri == total_rings - 2:
				_append_oriented_tri(indices, verts, norms, a, b, c, wind_sign)
			else:
				_append_oriented_tri(indices, verts, norms, a, b, d, wind_sign)
				_append_oriented_tri(indices, verts, norms, a, d, c, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func _ensure_eye_materials() -> void:
	if _eye_dark_mat == null:
		_eye_dark_mat = StandardMaterial3D.new()
		_eye_dark_mat.albedo_color = Color(0.18, 0.13, 0.11)
		_eye_dark_mat.roughness = 0.32
		_eye_dark_mat.metallic = 0.04
	if _eye_shine_mat == null:
		_eye_shine_mat = StandardMaterial3D.new()
		_eye_shine_mat.albedo_color = Color(1.0, 0.99, 0.96)
		_eye_shine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _blush_mat == null:
		_blush_mat = StandardMaterial3D.new()
		_blush_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blush_mat.albedo_color = Color(0.98, 0.56, 0.54, 0.58)
		_blush_mat.roughness = 0.78


static func attach_clay_eyes(
	parent: Node3D,
	forward_pos: Vector3,
	eye_spacing: float = 0.24,
	eye_radius: float = 0.065,
	with_blush: bool = true,
	force_build: bool = false,
	meta_owner: Node = null
) -> Node3D:
	if parent == null:
		return null
	parent.set_meta("has_clay_eyes", true)
	if meta_owner != null:
		meta_owner.set_meta("has_clay_eyes", true)
	var existing := parent.get_node_or_null("ClayEyes")
	if existing != null:
		parent.remove_child(existing)
		existing.free()

	if _is_headless() and not force_build:
		return null

	_ensure_eye_materials()
	var root := Node3D.new()
	root.name = "ClayEyes"
	root.position = forward_pos

	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = eye_radius
	pupil_mesh.height = eye_radius * 2.0
	pupil_mesh.radial_segments = 14
	pupil_mesh.rings = 8
	pupil_mesh.material = _eye_dark_mat

	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = eye_radius * 0.34
	shine_mesh.height = eye_radius * 0.68
	shine_mesh.radial_segments = 10
	shine_mesh.rings = 6
	shine_mesh.material = _eye_shine_mat

	for side_sign in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.mesh = pupil_mesh
		eye.position = Vector3(side_sign * eye_spacing * 0.5, 0.0, 0.0)
		eye.scale = Vector3(1.0, 1.12, 0.65)
		root.add_child(eye)

		var shine := MeshInstance3D.new()
		shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shine.mesh = shine_mesh
		shine.position = Vector3(
			side_sign * eye_spacing * 0.5 + eye_radius * 0.26,
			eye_radius * 0.30,
			eye_radius * 0.52
		)
		root.add_child(shine)

	if with_blush:
		var blush_mesh := SphereMesh.new()
		blush_mesh.radius = eye_radius * 0.78
		blush_mesh.height = eye_radius * 1.56
		blush_mesh.radial_segments = 12
		blush_mesh.rings = 6
		blush_mesh.material = _blush_mat
		for side_sign in [-1.0, 1.0]:
			var blush := MeshInstance3D.new()
			blush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			blush.mesh = blush_mesh
			blush.position = Vector3(
				side_sign * (eye_spacing * 0.5 + eye_radius * 1.15),
				-eye_radius * 0.55,
				-eye_radius * 0.08
			)
			blush.scale = Vector3(1.35, 0.72, 0.35)
			root.add_child(blush)

	parent.add_child(root)
	return root


static func make_ellipsoid_mesh(
	radii: Vector3,
	radial_segments: int = 32,
	rings: int = 18,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var rx := maxf(0.05, radii.x)
	var ry := maxf(0.05, radii.y)
	var rz := maxf(0.05, radii.z)
	var segs := clampi(radial_segments, 12, 64)
	var r_cnt := clampi(rings, 8, 40)
	var key := "ellip_%d_%d_%d_%d_%d" % [_q(rx), _q(ry), _q(rz), segs, r_cnt]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()

	for ir in range(r_cnt + 1):
		var v := float(ir) / float(r_cnt)
		var phi := PI * (0.5 - v)
		var cos_p := cos(phi)
		var sin_p := sin(phi)
		for iseg in range(segs + 1):
			var u := float(iseg) / float(segs)
			var theta := u * TAU
			var cos_t := cos(theta)
			var sin_t := sin(theta)
			var ux := cos_p * cos_t
			var uy := sin_p
			var uz := cos_p * sin_t
			verts.append(Vector3(rx * ux, ry * uy, rz * uz))
			var n := Vector3(ux / rx, uy / ry, uz / rz).normalized()
			norms.append(n if n.length_squared() > 0.0001 else Vector3.UP)
			uvs.append(Vector2(u, v))

	var stride := segs + 1
	for ir in range(r_cnt):
		for iseg in range(segs):
			var i0 := ir * stride + iseg
			var i1 := i0 + 1
			var i2 := i0 + stride
			var i3 := i2 + 1
			if ir > 0:
				_append_oriented_tri(indices, verts, norms, i0, i1, i3, wind_sign)
			if ir < r_cnt - 1:
				_append_oriented_tri(indices, verts, norms, i0, i3, i2, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func make_ellipsoid_convex_shape(
	radii: Vector3,
	radial_segments: int = 24,
	rings: int = 14
) -> ConvexPolygonShape3D:
	var rx := maxf(0.05, radii.x)
	var ry := maxf(0.05, radii.y)
	var rz := maxf(0.05, radii.z)
	var segs := clampi(radial_segments, 12, 48)
	var r_cnt := clampi(rings, 8, 32)

	var pts := PackedVector3Array()
	pts.append(Vector3(0.0, ry, 0.0))
	pts.append(Vector3(0.0, -ry, 0.0))
	for ir in range(1, r_cnt):
		var v := float(ir) / float(r_cnt)
		var phi := PI * (0.5 - v)
		var cos_p := cos(phi)
		var sin_p := sin(phi)
		for iseg in range(segs):
			var theta := (float(iseg) / float(segs)) * TAU
			pts.append(Vector3(rx * cos_p * cos(theta), ry * sin_p, rz * cos_p * sin(theta)))

	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	return shape
