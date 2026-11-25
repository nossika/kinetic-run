class_name GravityTiltController
extends RefCounted

const BASE_GRAVITY: float = 22.0
const BASE_PITCH_DEG: float = 11.0
const TILT_RESPONSE_SPEED_DEG: float = 240.0

var current_tilt_deg: float = 0.0


func reset() -> void:
	current_tilt_deg = 0.0


func update_tilt(input_axis: float, max_tilt_deg: float, delta: float, lateral_mult: float = 1.0) -> Vector3:
	var clamped_axis := clampf(input_axis, -1.0, 1.0)
	var limit_deg := clampf(max_tilt_deg, 20.0, 55.0)
	var target_deg := clamped_axis * limit_deg
	var step := TILT_RESPONSE_SPEED_DEG * maxf(0.5, lateral_mult) * maxf(0.0, delta)
	current_tilt_deg = move_toward(current_tilt_deg, target_deg, step)
	current_tilt_deg = clampf(current_tilt_deg, -limit_deg, limit_deg)
	return compute_gravity_vector(current_tilt_deg, 1.0)


func compute_gravity_vector(tilt_deg: float, g_scale: float = 1.0) -> Vector3:
	var phi := deg_to_rad(tilt_deg)
	var pitch := deg_to_rad(BASE_PITCH_DEG)
	var dir := Vector3(
		sin(phi) * cos(pitch),
		-cos(phi) * cos(pitch),
		-sin(pitch)
	).normalized()
	return dir * (BASE_GRAVITY * g_scale)


func apply_to_space(space_rid: RID, gravity_vec: Vector3) -> void:
	if not space_rid.is_valid():
		return
	var mag := gravity_vec.length()
	if mag <= 0.0001:
		PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, 0.0)
		return
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, gravity_vec / mag)
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, mag)
