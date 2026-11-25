class_name TrackEntityFactory
extends RefCounted


static func create_crate(pos: Vector3) -> CrateObstacle:
	var n := CrateObstacle.new()
	n.position = pos
	return n


static func create_slime_zone(pos: Vector3, size: Vector2 = Vector2(4.0, 6.0)) -> SlimeZone:
	var n := SlimeZone.new()
	n.zone_size = size
	n.position = pos
	return n


static func create_bouncer_slime(pos: Vector3, patrol_half_w: float = 2.6) -> BouncerSlime:
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
