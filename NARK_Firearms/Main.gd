extends Node

const MAGAZINES = ["Colt_1911_Magazine", "NARK_M45A1_Magazine"]
const WEAPONS = {
	"Colt_1911": ["Colt_1911_Magazine", "NARK_M45A1_Magazine"],
	"NARK_M45A1": ["NARK_M45A1_Magazine", "Colt_1911_Magazine"]
}

var _lib
var _hook_ids: Array = []
var _inventory_magazines: Dictionary = {}
var _world_magazines: Dictionary = {}
var _viewmodel_magazines: Dictionary = {}
var _materials: Array = []

func _ready():
	var lib = Engine.get_meta("RTVModLib", null)
	if lib == null or not lib.has_method("register"):
		return
	if lib.has_signal("frameworks_ready") and lib.get("_is_ready") == false:
		await lib.frameworks_ready
	_lib = lib
	for entry in [["Assets/MT_M45A1", "Assets/Albedo", "Assets/Normal"], ["Assets/MT_NDm", "Assets/NDm_Albedo", "Assets/NDm_Normal"], ["Beretta92FS/Assets/MT_Beretta", "Beretta92FS/Assets/Albedo", "Beretta92FS/Assets/Normal"]]:
		var material = load("res://NARK_Firearms/" + entry[0] + ".tres") as ShaderMaterial
		var albedo = load_texture("res://NARK_Firearms/" + entry[1] + ".png", false)
		var normal = load_texture("res://NARK_Firearms/" + entry[2] + ".png", true)
		if material == null or albedo == null or normal == null:
			return
		material.set_shader_parameter("albedo", albedo)
		material.set_shader_parameter("normal", normal)
		_materials.append(material)
	for entry in [["NARK_M45A1_Magazine", "M45A1_Magazine"], ["NARK_NDm_Laser", "NDm"], ["NARK_M45A1", "M45A1"], ["NARK_Beretta92FS_Magazine", "Beretta92FS/Beretta92FS_Magazine"], ["NARK_Beretta92FS", "Beretta92FS/Beretta92FS"]]:
		var item = load("res://NARK_Firearms/" + entry[1] + ".tres")
		var world = load("res://NARK_Firearms/" + entry[1] + ".tscn")
		if item == null or world == null:
			return
		lib.register("items", entry[0], item)
		lib.register("scenes", entry[0], world)
		lib.register("loot", entry[0] + "_Master", {"item": item, "table": "LT_Master"})
	var rig = load("res://NARK_Firearms/M45A1_Rig.tscn")
	if rig != null:
		lib.register("scenes", "NARK_M45A1_Rig", rig)
	var beretta_rig = load("res://NARK_Firearms/Beretta92FS/Beretta92FS_Rig.tscn")
	if beretta_rig != null:
		lib.register("scenes", "NARK_Beretta92FS_Rig", beretta_rig)
	configure_magazines()

func _exit_tree():
	if is_instance_valid(_lib) and _lib.has_method("unhook"):
		for id in _hook_ids:
			_lib.unhook(id)

func configure_magazines():
	var vanilla_weapon = load("res://Items/Weapons/Colt_1911/Colt_1911.tres")
	var vanilla_magazine = load("res://Items/Weapons/Colt_1911/Colt_1911_Magazine.tres")
	var weapon = load("res://NARK_Firearms/M45A1.tres")
	var magazine = load("res://NARK_Firearms/M45A1_Magazine.tres")
	if vanilla_weapon == null or vanilla_magazine == null or weapon == null or magazine == null:
		return
	append_magazine("Colt_1911", vanilla_weapon, magazine)
	append_magazine("NARK_M45A1", weapon, vanilla_magazine)
	_inventory_magazines["Colt_1911_Magazine"] = vanilla_magazine.tetris
	_inventory_magazines["NARK_M45A1_Magazine"] = magazine.tetris
	_world_magazines["Colt_1911_Magazine"] = load("res://Items/Weapons/Colt_1911/Colt_1911_Magazine_Static.tscn")
	_world_magazines["NARK_M45A1_Magazine"] = load("res://NARK_Firearms/M45A1_Magazine_Static.tscn")
	if _lib.has_method("hook"):
		_hook_ids.append(_lib.hook("item-initialize-post", _on_item_initialized, 960))
		_hook_ids.append(_lib.hook("pickup-updateattachments-post", _on_pickup_attachments, 960))

		_hook_ids.append(_lib.hook("weaponrig-_ready-post", _on_rig_magazine, 960))
		_hook_ids.append(_lib.hook("weaponrig-magazine-pre", _on_rig_magazine_change, 960))
		_hook_ids.append(_lib.hook("weaponrig-playmagazineattachempty-pre", _on_rig_magazine, 960))
		_hook_ids.append(_lib.hook("weaponrig-playmagazineattachtactical-pre", _on_rig_magazine, 960))

		_hook_ids.append(_lib.hook("weaponrig-updatebullets-pre", _on_rig_magazine, 960))

func append_magazine(id: String, fallback, magazine):
	var weapon = _lib.get_entry("items", id) if _lib.has_method("get_entry") else fallback
	if weapon == null:
		return
	for compatible in weapon.compatible:
		if compatible != null and compatible.file == magazine.file:
			return
	if _lib.has_method("append"):
		_lib.append("items", id, "compatible", [magazine])
	elif _lib.has_method("patch"):
		var compatible = weapon.compatible.duplicate()
		compatible.append(magazine)
		_lib.patch("items", id, {"compatible": compatible})

func _on_item_initialized(_source = null, _data = null, _result = null):
	var item = _lib.get("_caller")
	if not is_instance_valid(item):
		return
	var pair = magazine_pair(item.get("slotData"))
	if pair.is_empty():
		return
	var sprite = item.get("sprite") as Sprite2D
	if sprite == null or sprite.has_node(NodePath(pair[1])):
		return
	var scene = _inventory_magazines.get(pair[1]) as PackedScene
	if scene == null:
		return
	var node = scene.instantiate() as Sprite2D
	if node == null:
		return
	node.name = pair[1]
	node.visible = false
	node.show_behind_parent = true
	var existing = sprite.get_node_or_null(NodePath(pair[0])) as Sprite2D
	if existing != null:
		node.transform = existing.transform
	else:
		node.position = Vector2(-74, 14)
		node.scale = Vector2(1.2, 1.2)
	sprite.add_child(node)
	for nested in item.slotData.nested:
		if nested != null and nested.file == pair[1]:
			node.visible = true
			item.set("magazine", true)
			item.UpdateSprite()
			break

func _on_pickup_attachments(_result = null):
	var pickup = _lib.get("_caller")
	if not is_instance_valid(pickup):
		return
	var slot = pickup.get("slotData")
	var pair = magazine_pair(slot)
	if pair.is_empty():
		return
	var attachments = pickup.get_node_or_null("Attachments")
	if attachments == null:
		return
	if not attachments.has_node(NodePath(pair[1])):
		var scene = _world_magazines.get(pair[1]) as PackedScene
		if scene == null:
			return
		var node = scene.instantiate() as Node3D
		if node == null:
			return
		node.name = pair[1]
		node.visible = false
		var existing = attachments.get_node_or_null(NodePath(pair[0])) as Node3D
		if existing != null:
			node.transform = existing.transform
		else:
			node.position = Vector3(0, -0.065, -0.02)
		attachments.add_child(node)
	for id in MAGAZINES:
		var node = attachments.get_node_or_null(NodePath(id)) as Node3D
		if node != null:
			node.visible = false
			for nested in slot.nested:
				if nested != null and nested.file == id:
					node.visible = true
					break

func magazine_pair(slot) -> Array:
	if slot == null or slot.itemData == null:
		return []
	return WEAPONS.get(slot.itemData.file, [])

func _on_rig_magazine(_result = null):
	update_rig_magazine(_lib.get("_caller"))

func _on_rig_magazine_change(attach = false, animate = false, _result = null):
	if not attach:
		return
	var rig = _lib.get("_caller")
	if not is_instance_valid(rig):
		return
	var magazine = rig.get("magazine") as MeshInstance3D
	if not animate or magazine == null or not magazine.visible:
		update_rig_magazine(rig)

func update_rig_magazine(rig):
	if not is_instance_valid(rig):
		return
	var slot = rig.get("slotData")
	var pair = magazine_pair(slot)
	if pair.is_empty():
		return
	var magazine = rig.get("magazine") as MeshInstance3D
	if magazine == null or magazine.mesh == null:
		return
	var attached_id = ""
	for nested in slot.nested:
		if nested != null and nested.subtype == "Magazine":
			attached_id = nested.file
			break
	if attached_id.is_empty():
		return
	var replacement = magazine.get_node_or_null("NARK_Ammo_Magazine") as MeshInstance3D
	if attached_id != pair[1]:
		if replacement != null:
			replacement.hide()
		if magazine.has_meta("nark_m45a1_magazine_layers"):
			magazine.layers = int(magazine.get_meta("nark_m45a1_magazine_layers"))
			magazine.remove_meta("nark_m45a1_magazine_layers")
		return
	if replacement == null:
		var source = viewmodel_magazine(attached_id)
		if source.is_empty():
			return
		var skeleton = magazine.get_node_or_null(magazine.skeleton) as Skeleton3D
		if skeleton == null:
			return
		replacement = MeshInstance3D.new()
		replacement.name = "NARK_Ammo_Magazine"
		replacement.mesh = source.mesh
		replacement.skin = magazine.skin
		replacement.cast_shadow = magazine.cast_shadow
		replacement.material_override = source.get("material_override")
		for index in replacement.mesh.get_surface_count():
			replacement.set_surface_override_material(index, source.get("surface_material_override/" + str(index)))
		magazine.add_child(replacement)
		replacement.skeleton = replacement.get_path_to(skeleton)
	if not magazine.has_meta("nark_m45a1_magazine_layers") or magazine.layers != 0:
		magazine.set_meta("nark_m45a1_magazine_layers", magazine.layers)
	replacement.layers = int(magazine.get_meta("nark_m45a1_magazine_layers"))
	magazine.layers = 0
	replacement.show()

func viewmodel_magazine(id: String) -> Dictionary:
	if _viewmodel_magazines.has(id):
		return _viewmodel_magazines[id]
	var path = "res://Items/Weapons/Colt_1911/Colt_1911_Rig.tscn" if id == "Colt_1911_Magazine" else "res://NARK_Firearms/M45A1_Rig.tscn"
	var scene = load(path) as PackedScene
	if scene == null:
		return {}
	var state = scene.get_state()
	for node in state.get_node_count():
		if state.get_node_name(node) != &"Magazine" or state.get_node_type(node) != &"MeshInstance3D":
			continue
		var source: Dictionary = {}
		for property in state.get_node_property_count(node):
			var name = str(state.get_node_property_name(node, property))
			if name == "mesh" or name == "material_override" or name.begins_with("surface_material_override/"):
				source[name] = state.get_node_property_value(node, property)
		if source.get("mesh") is Mesh:
			_viewmodel_magazines[id] = source
			return source
	return {}

func load_texture(path: String, normal: bool) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image = Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	if image.generate_mipmaps(normal) != OK:
		return null
	return ImageTexture.create_from_image(image)
