extends RefCounted

var _lib
var _config
var _rig:WeakRef
var _handling:WeakRef
var _position=Vector3.ZERO
var _basis=Basis.IDENTITY
var _rotate=false

func configure(lib,vostac) -> bool:
 _config=vostac.get("config")
 if _config==null or not _config.has_method("gated") or not _config.has_method("locked"):return false
 _lib=lib
 lib.hook("rigmanager-updaterig-post",_on_rig_update,300)
 lib.hook("handling-weaponhandling-post",_on_handling,150)
 return true

func _on_rig_update(_animate:bool):
 _rig=null;_handling=null;_position=Vector3.ZERO;_basis=Basis.IDENTITY;_rotate=false
 var manager=_lib._caller
 if manager==null or manager.get_child_count()==0:return
 var rig=manager.get_child(manager.get_child_count()-1)
 if not rig.has_method("_vm_vostac_active") or not rig._vm_vostac_active():return
 var handling=rig.get_node_or_null("Handling")
 if handling==null:return
 _rig=weakref(rig);_handling=weakref(handling)
 if handling.has_method("_vm_ads_basis"):
  handling._vm_vostac=true
  _position=handling.ads_position
  _basis=handling._vm_ads_basis()
  _rotate=handling.ads_rotation!=Vector3.ZERO
 rig.UpdateAimOffset()

func _on_handling(_delta:float):
 if _rig==null or _handling==null or _config.gated() or _config.locked():return
 var rig=_rig.get_ref()
 var handling=_handling.get_ref()
 if rig==null or handling==null or _lib._caller!=handling:return
 var gd=handling.gameData
 if not gd.isAiming or gd.isCanted or gd.isClearing or gd.isColliding or gd.isRunning or _config.binoculars_active:return
 var optic=rig.activeOptic
 if optic!=null and rig._vm_optic_aim.has(str(optic.name)):
  var reference=rig._vm_optic_aim[str(optic.name)]
  rig.aimOffset=reference.height
  if gd.secondaryOptic and optic.secondary!=null:rig.aimOffset+=reference.secondary_height
  handling.targetPosition.y=-rig.aimOffset
 handling.targetPosition+=_position
 if _rotate:handling.targetRotation=(_basis*Basis.from_euler(handling.targetRotation*PI/180.0)).get_euler()*180.0/PI
