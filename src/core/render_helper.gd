class_name RenderHelper
extends RefCounted


static func attach_mesh(mesh_inst: MeshInstance3D, mesh_res: Mesh) -> void:
	if mesh_inst == null or mesh_res == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	mesh_inst.mesh = mesh_res
