class_name TrackEntityFactory
extends RefCounted


static func create_crate(pos: Vector3, tier: String = "light", yaw_deg: float = 0.0) -> CrateObstacle:
	var n := CrateObstacle.new()
	n.configure_tier(tier)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	return n


static func create_heavy_crate(pos: Vector3, yaw_deg: float = 0.0) -> CrateObstacle:
	return create_crate(pos, "medium", yaw_deg)


static func create_wooden_pin(pos: Vector3) -> WoodenPin:
	var n := WoodenPin.new()
	n.position = pos
	return n


static func create_slime_zone(pos: Vector3, size: Vector2 = Vector2(4.0, 6.0)) -> SlimeZone:
	var n := SlimeZone.new()
	n.zone_size = size
	n.position = pos
	return n


static func create_bouncer_slime(pos: Vector3, patrol_half_w: float = 3.5) -> BouncerSlime:
	var n := BouncerSlime.new()
	n.patrol_half_width = patrol_half_w
	n.position = pos
	return n


static func create_shield_brute(pos: Vector3) -> ShieldBrute:
	var n := ShieldBrute.new()
	n.position = pos
	return n


static func create_boost_pad(pos: Vector3) -> BoostPad:
	var n := BoostPad.new()
	n.position = pos
	return n


static func create_pinball_bumper(pos: Vector3) -> PinballBumper:
	var n := PinballBumper.new()
	n.position = pos
	return n


static func create_explosive_barrel(pos: Vector3) -> ExplosiveBarrel:
	var n := ExplosiveBarrel.new()
	n.position = pos
	return n


static func create_spring_pad(pos: Vector3) -> SpringPad:
	var n := SpringPad.new()
	n.position = pos
	return n


static func create_aerial_bonus_ring(pos: Vector3) -> AerialBonusRing:
	var n := AerialBonusRing.new()
	n.position = pos
	return n


static func create_aerial_blocker(
	pos: Vector3,
	blocker_type: String = "soft_balloon",
	initial_phase: float = 0.0
) -> AerialBlocker:
	var n := AerialBlocker.new()
	n.configure_type(blocker_type, initial_phase)
	n.position = pos
	return n


static func create_wind_zone(
	pos: Vector3,
	zone_size: Vector3 = Vector3(6.0, 3.6, 12.0),
	preset: String = "cross_right",
	force_newtons: float = -1.0
) -> WindZone:
	var n := WindZone.new()
	n.configure_wind(zone_size, preset, force_newtons)
	n.position = pos
	return n
