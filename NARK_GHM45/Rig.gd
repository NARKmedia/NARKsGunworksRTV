extends "res://NARK_Firearms/WeaponRuntime.gd"

func _init():
 _vm_config_path="res://NARK_GHM45/Weapon.json"
 _vm_model_scene=preload("res://NARK_GHM45/Assets/Model.tscn")
 _vm_material=preload("res://NARK_GHM45/Material.tres")
