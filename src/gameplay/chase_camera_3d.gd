class_name ChaseCamera3D
extends Camera3D

const FOLLOW_OFFSET := Vector3(0.0, 5.6, 8.8)
const BASE_PITCH_DEG: float = -27.0
const ROLL_FACTOR: float = 0.0
const BASE_FOV: float = 65.0
const MAX_FOV: float = 88.0

var _shake_trauma: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	fov = BASE_FOV
	near = 0.15
	far = 350.0


func snap_to_target(ball_pos: Vector3) -> void:
	position = ball_pos + FOLLOW_OFFSET
	rotation_degrees = Vector3(BASE_PITCH_DEG, 0.0, 0.0)
	fov = BASE_FOV
	_shake_trauma = 0.0


func add_shake(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func update_camera(ball_pos: Vector3, _tilt_deg: float, speed_mps: float, delta: float) -> void:
	var speed_ratio := clampf(speed_mps / 55.0, 0.0, 1.0)
	var dynamic_offset := FOLLOW_OFFSET + Vector3(0.0, 0.7 * speed_ratio, 1.4 * speed_ratio)
	var target_pos := ball_pos + dynamic_offset

	var pos_lerp := clampf(10.0 * delta, 0.0, 1.0)
	position.x = lerpf(position.x, target_pos.x * 0.78, pos_lerp)
	position.y = lerpf(position.y, target_pos.y, pos_lerp)
	position.z = target_pos.z

	rotation_degrees = Vector3(BASE_PITCH_DEG, 0.0, 0.0)

	var target_fov := lerpf(BASE_FOV, MAX_FOV, speed_ratio)
	fov = lerpf(fov, target_fov, clampf(7.0 * delta, 0.0, 1.0))

	if _shake_trauma > 0.001:
		_shake_time += delta * 38.0
		var mag := _shake_trauma * _shake_trauma * 0.35
		h_offset = sin(_shake_time * 1.3) * mag
		v_offset = cos(_shake_time * 1.9) * mag
		_shake_trauma = maxf(0.0, _shake_trauma - 2.4 * delta)
	else:
		h_offset = 0.0
		v_offset = 0.0
