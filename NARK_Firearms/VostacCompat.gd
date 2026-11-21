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
 _configure_break_action(rig)

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

func _configure_break_action(rig):
 if not rig.has_method("_ba_control_open") or not rig.get("_ba_ready"):return
 if rig.get_node_or_null("GunworksVostacBreakAction")!=null:return
 var manual=rig.get_node_or_null("Likho_WeaponRig_ManualReload")
 var reload=rig.get_node_or_null("Likho_WeaponRig_Reload")
 # Only take ownership of the known handlers on this one live rig.
 if not _handler_matches(manual,"WeaponRig_ManualReload.gd") or not _handler_matches(reload,"WeaponRig_Reload.gd") or not reload.has_method("_do_reload"):return
 var bridge=load("res://NARK_Firearms/VostacBreakAction.gd").new()
 bridge.name="GunworksVostacBreakAction"
 bridge.configure(rig,_config,reload)
 rig.add_child(bridge)
 for handler in [manual,reload]:
  handler.set_process_input(false)
  handler.set_process(false)
  handler.set_physics_process(false)

func _handler_matches(node,filename: String) -> bool:
 if node==null:return false
 var script=node.get_script()
 return script!=null and script.resource_path=="res://mods/likhos-vostac/Scripts/Nodes/"+filename
