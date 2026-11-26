class_name RenderHelper
extends RefCounted


static func attach_mesh(mesh_inst: MeshInstance3D, mesh_res: Mesh) -> void:
	if mesh_inst == null or mesh_res == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	mesh_inst.mesh = mesh_res
	var eff_mat: Material = mesh_inst.material_override
	if eff_mat == null and mesh_res is PrimitiveMesh:
		eff_mat = (mesh_res as PrimitiveMesh).material
	sync_outline_hull(mesh_inst, mesh_res, eff_mat)


static func sync_outline_hull(mesh_inst: MeshInstance3D, mesh_res: Mesh, mat: Material) -> void:
	if mesh_inst == null or DisplayServer.get_name() == "headless":
		return
	var existing := mesh_inst.get_node_or_null("ToonOutlineHull")
	if existing != null:
		mesh_inst.remove_child(existing)
		existing.free()
	if mesh_res == null or mat == null or mat.next_pass == null:
		return
	if mesh_res is TorusMesh:
		return
	var hull := MeshInstance3D.new()
	hull.name = "ToonOutlineHull"
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hull.mesh = mesh_res
	hull.material_override = mat.next_pass
	mesh_inst.add_child(hull)
