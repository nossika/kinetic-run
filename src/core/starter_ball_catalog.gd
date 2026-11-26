class_name StarterBallCatalog
extends RefCounted

const SHAPES: Array[Dictionary] = [
	{
		"type": "sphere",
		"label": "圆球",
		"hint": "全向灵巧变道",
	},
	{
		"type": "rugby",
		"label": "橄榄球",
		"hint": "擦碰俏皮弹跃",
	},
	{
		"type": "capsule_roller",
		"label": "圆边滚筒",
		"hint": "宽幅压线扫障",
	},
]

const LIVERIES: Array[Dictionary] = [
	{
		"id": "beach",
		"noun": "沙滩",
		"tex": MaterialLibrary.TEX_BALL_LIVERY_BEACH,
		"accent": Color(0.92, 0.36, 0.30),
		"secondary": Color(0.24, 0.64, 0.92),
	},
	{
		"id": "racer",
		"noun": "星章",
		"tex": MaterialLibrary.TEX_BALL_LIVERY_RACER,
		"accent": Color(0.20, 0.46, 0.88),
		"secondary": Color(0.94, 0.32, 0.26),
	},
	{
		"id": "swirl",
		"noun": "糖果",
		"tex": MaterialLibrary.TEX_BALL_LIVERY_SWIRL,
		"accent": Color(0.18, 0.74, 0.48),
		"secondary": Color(0.94, 0.38, 0.42),
	},
	{
		"id": "polka",
		"noun": "波点",
		"tex": MaterialLibrary.TEX_BALL_LIVERY_POLKA,
		"accent": Color(0.95, 0.72, 0.16),
		"secondary": Color(0.22, 0.44, 0.86),
	},
]

const TINT_PALETTES: Array[Dictionary] = [
	{"tint": Color(1.00, 1.00, 1.00), "adj": "明快"},
	{"tint": Color(1.04, 0.94, 0.90), "adj": "蜜桃"},
	{"tint": Color(0.92, 1.00, 0.98), "adj": "薄荷"},
	{"tint": Color(1.03, 0.99, 0.88), "adj": "暖阳"},
	{"tint": Color(0.93, 0.95, 1.05), "adj": "晴空"},
]


static func _round_step(val: float, step: float) -> float:
	return round(val / step) * step


static func _shuffle_indices(n: int, rng: RandomNumberGenerator) -> Array[int]:
	var arr: Array[int] = []
	for i in range(n):
		arr.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr


static func roll_starter_balls(run_seed: int, count: int = 3) -> Array[StarterBallDefinition]:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.derive_starter_ball_seed(run_seed)

	var shape_order := _shuffle_indices(SHAPES.size(), rng)
	var livery_order := _shuffle_indices(LIVERIES.size(), rng)
	var profile_order := _shuffle_indices(3, rng)

	var results: Array[StarterBallDefinition] = []
	var total := maxi(1, count)

	for slot in range(total):
		var def := StarterBallDefinition.new()
		var shape_info: Dictionary = SHAPES[shape_order[slot % SHAPES.size()]]
		var liv_info: Dictionary = LIVERIES[livery_order[slot % LIVERIES.size()]]
		var pal_info: Dictionary = TINT_PALETTES[rng.randi_range(0, TINT_PALETTES.size() - 1)]

		def.shape_type = String(shape_info["type"])
		def.shape_label = String(shape_info["label"])
		def.livery_id = String(liv_info["id"])
		def.livery_texture_path = String(liv_info["tex"])
		def.primary_tint = pal_info["tint"] as Color
		def.accent_color = liv_info["accent"] as Color
		def.secondary_color = liv_info["secondary"] as Color

		# Distinct physical flavor bias per shuffled archetype slot, plus seed variance
		var bias := profile_order[slot % 3]
		var raw_mass := 1.5
		var raw_radius := 0.55
		var raw_bounce := 0.30
		var raw_friction := 0.45
		var raw_damp := 0.32

		match bias:
			0:
				# Heavy crusher / juggernaut bias
				raw_mass = rng.randf_range(2.25, 3.45)
				raw_radius = rng.randf_range(0.58, 0.72)
				raw_bounce = rng.randf_range(0.12, 0.38)
				raw_friction = rng.randf_range(0.48, 0.82)
				raw_damp = rng.randf_range(0.24, 0.36)
			1:
				# High-bounce agile trickster bias
				raw_mass = rng.randf_range(0.90, 1.55)
				raw_radius = rng.randf_range(0.45, 0.57)
				raw_bounce = rng.randf_range(0.58, 0.84)
				raw_friction = rng.randf_range(0.32, 0.66)
				raw_damp = rng.randf_range(0.20, 0.32)
			_:
				# Balanced / slick speedster or grippy all-rounder
				raw_mass = rng.randf_range(1.30, 2.20)
				raw_radius = rng.randf_range(0.50, 0.65)
				raw_bounce = rng.randf_range(0.26, 0.58)
				raw_friction = rng.randf_range(0.20, 0.78)
				raw_damp = rng.randf_range(0.18, 0.34)

		def.mass = clampf(_round_step(raw_mass, 0.1), 0.85, 3.60)
		def.radius = clampf(_round_step(raw_radius, 0.02), 0.44, 0.74)
		def.bounce = clampf(_round_step(raw_bounce, 0.05), 0.10, 0.85)
		def.friction = clampf(_round_step(raw_friction, 0.05), 0.20, 0.85)
		def.linear_damp = clampf(_round_step(raw_damp, 0.02), 0.18, 0.48)

		var prefix := _pick_trait_prefix(def, String(pal_info["adj"]))
		def.display_name = "%s%s%s" % [prefix, String(liv_info["noun"]), def.shape_label]
		def.tagline = "%s · %s" % [_describe_stat_highlight(def), String(shape_info["hint"])]
		def.id = "starter_%d_%s_%s" % [slot, def.shape_type, def.livery_id]
		results.append(def)

	return results


static func _pick_trait_prefix(def: StarterBallDefinition, fallback_adj: String) -> String:
	if def.mass >= 2.55:
		return "重装"
	if def.bounce >= 0.65:
		return "高弹"
	if def.radius >= 0.65:
		return "大号"
	if def.radius <= 0.48:
		return "迷你"
	if def.friction <= 0.28:
		return "溜冰"
	if def.friction >= 0.72:
		return "抓地"
	return fallback_adj


static func _describe_stat_highlight(def: StarterBallDefinition) -> String:
	if def.mass >= 2.4:
		return "大质量强力破障"
	if def.bounce >= 0.60:
		return "超强碰撞弹力"
	if def.friction <= 0.30:
		return "低摩擦顺滑疾驰"
	if def.friction >= 0.70:
		return "稳健高抓地咬合"
	return "均衡物理手感"
