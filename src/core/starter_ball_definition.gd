class_name StarterBallDefinition
extends RefCounted

var id: String = ""
var display_name: String = "糖果彩球"
var tagline: String = "均衡顺滑 · 全向好滚"
var shape_type: String = "sphere" # "sphere", "rugby", "capsule_roller"
var shape_label: String = "圆球"

var mass: float = 1.5
var radius: float = 0.55
var bounce: float = 0.25
var friction: float = 0.42
var linear_damp: float = 0.35

var livery_id: String = "beach" # "beach", "racer", "swirl", "polka"
var livery_texture_path: String = MaterialLibrary.TEX_BALL_LIVERY_BEACH
var primary_tint: Color = Color.WHITE
var accent_color: Color = Color(0.92, 0.38, 0.32)
var secondary_color: Color = Color(0.24, 0.62, 0.90)


func format_summary_line() -> String:
	return "%s（%s | %.1fkg | 半径%.2fm | 弹性%.0f%% | 摩擦%.0f%%）" % [
		display_name,
		shape_label,
		mass,
		radius,
		bounce * 100.0,
		friction * 100.0,
	]
