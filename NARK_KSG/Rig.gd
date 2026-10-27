extends "res://NARK_Firearms/WeaponRuntime.gd"

func _init():
 _vm_config_path="res://NARK_KSG/Weapon.json"
 _vm_model_scene=preload("res://NARK_KSG/Assets/Model.tscn")
 _vm_material=preload("res://NARK_KSG/Material.tres")
