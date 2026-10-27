extends "res://Scripts/Handling.gd"

const Calibration=preload("res://NARK_Firearms/AdsPose.gd")
@export var ads_position=Vector3.ZERO
@export var ads_rotation=Vector3.ZERO
var _ads_basis=Basis.IDENTITY
var _ads_rotate=false
var _vm_vostac=false

func _ready():
 super._ready()
 _ads_basis=Calibration.native_basis(ads_rotation)
 _ads_rotate=ads_rotation!=Vector3.ZERO

func _vm_ads_basis() -> Basis:
 return _ads_basis

func WeaponHandling(delta):
 super.WeaponHandling(delta)
 if _vm_vostac:return
 if not gameData.isAiming or gameData.freeze or gameData.isClearing or collision.is_colliding() or gameData.isPlacing or gameData.isInspecting or gameData.isRunning or gameData.isChecking or (gameData.isReloading and data.weaponAction!="Manual"):return
 targetPosition+=ads_position
 if _ads_rotate:targetRotation=(_ads_basis*Basis.from_euler(targetRotation*PI/180.0)).get_euler()*180.0/PI
