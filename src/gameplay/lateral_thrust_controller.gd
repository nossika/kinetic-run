class_name LateralThrustController
extends RefCounted

const WORLD_GRAVITY := Vector3(0.0, -22.0, 0.0)
const BASE_LATERAL_ACCEL: float = 20.0
const AIR_LATERAL_FACTOR: float = 0.65

var current_axis: float = 0.0


func reset() -> void:
	current_axis = 0.0


func compute_lateral_accel(input_axis: float, lateral_mult: float = 1.0, is_airborne: bool = false) -> float:
	if absf(input_axis) < 0.01:
		current_axis = 0.0
		return 0.0
	current_axis = clampf(input_axis, -1.0, 1.0)
	var air_factor := AIR_LATERAL_FACTOR if is_airborne else 1.0
	return current_axis * BASE_LATERAL_ACCEL * maxf(0.0, lateral_mult) * air_factor


func apply_vertical_gravity_to_space(space_rid: RID) -> void:
	if not space_rid.is_valid():
		return
	var mag := WORLD_GRAVITY.length()
	if mag <= 0.0001:
		PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, 0.0)
		return
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, WORLD_GRAVITY / mag)
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, mag)
