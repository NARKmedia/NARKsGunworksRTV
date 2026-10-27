extends "res://Scripts/WeaponRig.gd"

var _vm_model_scene: PackedScene
var _vm_material: ShaderMaterial
var _vm_config_path: String
var _vm_config: Dictionary
var _vm_weapon: Skeleton3D
var _vm_voices: Array = []
var _vm_sounds: Dictionary = {}
var _vm_native_sounds: Dictionary = {}
var _vm_voice_index = 0
var _vm_states
var _vm_sights
var _vm_optic_aim:Dictionary={}

func _ready():
 _vm_config = JSON.parse_string(FileAccess.get_file_as_string(_vm_config_path))
 var holder = get_node("Handling/Sway/Noise/Tilt/Impulse/Recoil/Holder/"+_vm_config.base)
 holder.get_node("Armature/Skeleton3D").hide()
 var model = _vm_model_scene.instantiate()
 holder.add_child(model)
 model.name = "VosModel"
 arms = model.get_node("ArmsRig/Skeleton3D/Arms")
 skeleton = model.get_node("ArmsRig/Skeleton3D")
 var ammo = model.get_node_or_null("AmmoRig/Skeleton3D/Ammo")
 if ammo != null:
  cartridge = ammo
 var custom_magazine = model.get_node_or_null("MagazineRig/Skeleton3D/Magazine")
 if custom_magazine != null:
  magazine = custom_magazine
 var weapon_mesh = model.get_node("WeaponRig/Skeleton3D/Weapon") as MeshInstance3D
 for mesh in model.find_children("*", "MeshInstance3D", true, false):
  if mesh != arms:
   for surface in mesh.mesh.get_surface_count():
    mesh.set_surface_override_material(surface, _vm_material)
 arms.set_surface_override_material(0, load("res://Items/Clothing/Jacket_M62/Files/MT_Jacket_M62_Sleeves.tres"))
 if arms.mesh.get_surface_count() > 1:
  arms.set_surface_override_material(1, load("res://Items/Clothing/Gloves_Leather/Files/MT_Gloves_Leather.tres"))
 _vm_config = JSON.parse_string(FileAccess.get_file_as_string(_vm_config_path))
 _vm_weapon = model.get_node("WeaponRig/Skeleton3D")
 if not _vm_config.game_parts.is_empty():
  _vm_states = load("res://NARK_Firearms/PartStates.gd").new()
  _vm_weapon.add_child(_vm_states)

 var attachment = BoneAttachment3D.new()
 attachment.name = "VosModelReferences"
 attachment.bone_name = _vm_weapon.get_bone_name(0)
 attachment.bone_idx = 0
 _vm_weapon.add_child(attachment)
 var references = Node3D.new()
 attachment.add_child(references)
 references.transform = weapon_mesh.skin.get_bind_pose(0)
 muzzle = Node3D.new()
 references.add_child(muzzle)
 muzzle.position = _vm_vec(_vm_config.muzzle)
 muzzle.rotation_degrees = _vm_vec(_vm_config.muzzle_rotation)
 ejector = Node3D.new()
 references.add_child(ejector)
 ejector.position = _vm_vec(_vm_config.ejector)
 ejector.rotation_degrees = _vm_vec(_vm_config.ejector_rotation)
 raycast = RayCast3D.new()
 references.add_child(raycast)
 raycast.transform = muzzle.transform
 raycast.target_position = Vector3(0, 0, 400)
 raycast.collision_mask = 93
 if _vm_config.audio.values().any(func(value):return value not in ["vanilla:","silent:",""] and not str(value).begins_with("native:")) or _vm_config.events.any(func(event):return event.type=="sound" and not str(event.file).begins_with("native:")):
  for i in 8:
   var voice=AudioStreamPlayer3D.new()
   voice.bus="Master"
   add_child(voice)
   _vm_voices.append(voice)
 var source_player = model.get_node("AnimationPlayer") as AnimationPlayer
 source_player.active = false
 var replacements = AnimationLibrary.new()
 for animation_name in animations.get_animation_list():
  var slot = str(animation_name).trim_prefix(str(_vm_config.base)+"_")
  var source_name = slot if source_player.has_animation(slot) else "Idle"
  var clip = source_player.get_animation(source_name).duplicate(true) as Animation
  clip.loop_mode = Animation.LOOP_LINEAR if slot in ["Idle","Insert_Idle"] else Animation.LOOP_NONE
  for track in clip.get_track_count():
   clip.track_set_path(track, NodePath("VosModel/" + str(clip.track_get_path(track))))
  for event in _vm_config.events:
   if event.slot != slot:
    continue
   if event.type == "part_state" and event.action!="set":continue
   var track = clip.add_track(Animation.TYPE_METHOD)
   clip.track_set_path(track, animations.get_parent().get_path_to(self))
   if event.type == "part_state":
    clip.track_insert_key(track,min(float(event.frame)/60.0,clip.length),{"method": &"_vm_part_action", "args": [event.kind,event.state,float(event.get("duration",0)),event.slot,str(event.kind)+":"+str(event.frame)]})
    continue
   var method = &"CasingEject" if event.type=="eject" else &"_vm_sound"
   var args = [event.file] if event.type=="sound" else []
   clip.track_insert_key(track, min(float(event.frame) / 60.0,clip.length), {"method": method, "args": args})
  replacements.add_animation(animation_name, clip)
 animations.remove_animation_library("")
 animations.add_animation_library("", replacements)
 if not _vm_config.get("library_mounts",[]).is_empty():
  var mounts=load("res://NARK_Firearms/LibraryMounts.gd").new()
  _vm_weapon.add_child(mounts)
  mounts.configure(self,model,_vm_config.library_mounts)
 dynamicSlide = false
 dynamicSelector = false
 dynamicHammer = false
 selectorIndex = 0
 super._ready()
 var sight_rule=_vm_config.get("optic_sights",{})
 if sight_rule.get("enabled",false) and not sight_rule.get("parts",[]).is_empty():
  _vm_sights=load("res://NARK_Firearms/OpticSights.gd").new()
  _vm_weapon.add_child(_vm_sights)
  _vm_sights.configure(sight_rule.parts,activeOptic!=null)
 if slotData.itemData!=null and str(slotData.itemData.file)==str(_vm_config.item_id):
  slotData.itemData.set("caliber",str(_vm_config.caliber))
 if _vm_states!=null:_vm_states.configure(self,_vm_config.game_parts,_vm_config.events)
 if _vm_config.get("library_mounts",[]).any(func(m):return m.subtype=="Magazine"):
  var visuals=load("res://NARK_Firearms/LibraryMagazines.gd").new()
  add_child(visuals);visuals.configure(self,model,_vm_config.library_mounts,_vm_config.get("imported_magazine_id",""))

func _vm_vec(value) -> Vector3:
 return Vector3(value[0], value[1], value[2])

func _physics_process(delta):
 super._physics_process(delta)
 if gameData.freeze or gameData.isCaching or gameData.isPlacing or gameData.isDrawing:return
 if data.weaponAction=="Manual" and currentState=="Idle" and not gameData.isReloading and slotData.chamber and slotData.casing:
  slotData.casing=false
  if weaponSlot!=null and weaponSlot.get_child_count()>0:weaponSlot.get_child(0).UpdateDetails()

func UpdateAimOffset():
 super.UpdateAimOffset()
 if activeOptic!=null and _vm_optic_aim.has(str(activeOptic.name)):
  var reference=_vm_optic_aim[str(activeOptic.name)]
  aimOffset=reference.height
  if gameData.secondaryOptic and activeOptic.secondary:aimOffset+=reference.secondary_height
 if _vm_sights!=null:_vm_sights.set_optic(activeOptic!=null)

func _vm_sound(path: String):
 if path.begins_with("native:"):
  _vm_play_native(path.trim_prefix("native:"))
  return
 if path=="" or _vm_voices.is_empty():return
 if not _vm_sounds.has(path):
  _vm_sounds[path]=load(path.trim_prefix("native_stream:")) as AudioStream if path.begins_with("native_stream:") else AudioStreamWAV.load_from_file(path)
 var sound=_vm_sounds[path]
 if sound==null:return
 var voice=_vm_voices[_vm_voice_index]
 _vm_voice_index=(_vm_voice_index+1)%_vm_voices.size()
 voice.stream=sound
 voice.play()

func _vm_audio_key(key: String):
 var choice=str(_vm_config.audio.get(key,"vanilla:"))
 if choice=="silent:":return
 if choice.begins_with("native:"):
  _vm_play_native(choice.trim_prefix("native:"))
  return
 if choice!="vanilla:":
  _vm_sound(choice)
  return
 if key=="mode":
  super.PlayFiremode()
  return
 var native_key=key
 if key in ["tail_indoor","tail_outdoor"] and activeMuzzle!=null:native_key+="_suppressed"
 var path=str(_vm_config.vanilla_audio.get(native_key,""))
 if path=="":return
 _vm_play_native(path)

func _vm_play_native(path: String):
 if not _vm_native_sounds.has(path):_vm_native_sounds[path]=load(path)
 if _vm_native_sounds[path]==null:return
 var voice=audioInstance2D.instantiate()
 get_tree().root.add_child(voice)
 voice.PlayInstance(_vm_native_sounds[path])

func PlayFire():
 if _vm_states!=null:_vm_states.on_shot()
 var key="suppressed" if activeMuzzle!=null else "fire_auto" if slotData.mode==2 else "fire"
 _vm_audio_key(key)

func PlayTail():
 _vm_audio_key("tail_indoor" if gameData.indoor else "tail_outdoor")

func PlayFiremode():
 _vm_audio_key("mode")

func _vm_part_action(kind: String,state: String,frames: float,slot: String,cue: String):
 if _vm_states!=null:_vm_states.request(kind,state,frames,slot,cue)

func PlayMagazineAttachEmpty():
 pass

func PlayMagazineAttachTactical():
 pass

func PlayMagazineDetach():
 pass

func PlayAmmoCheck():
 pass

func PlayReloadEmpty():
 pass

func PlayReloadTactical():
 pass

func PlayInsertStart():
 pass

func PlayInsertEnd():
 pass

func PlayInsert():
 pass

func PlayReload():
 pass

func PlayMalfunction():
 pass

func PlayMalfunctionClear():
 pass

func PlayInspectStart():
 pass

func PlayInspectRotate():
 pass

func PlayInspectEnd():
 pass

func PlayRailMove():
 pass

func PlayCasingDrop():
 pass


func Insert():
 if _vm_config.get("chamber_on_insert_end",true):
  super.Insert()
  return

 if gameData.isInspecting || gameData.isReloading || gameData.isFiring || gameData.isClearing:
  return



 if Input.is_action_just_pressed(("prepare")):

  if !gameData.isInserting && currentState == "Idle":
   PlayInsertStart()
   animator["parameters/conditions/Insert_Start"] = true
   animator["parameters/conditions/Insert_End"] = false
   gameData.isInserting = true
   return

  if gameData.isInserting && currentState == "Insert_Idle":
   PlayInsertEnd()
   animator["parameters/conditions/Insert_Start"] = false
   animator["parameters/conditions/Insert_End"] = true
   gameData.isInserting = false


 if Input.is_action_just_pressed(("insert")) && gameData.isInserting && currentState == "Insert_Idle":

  if slotData.amount == data.maxAmount:
   return

  if interface.GetAmmo(data):
   PlayInsert()
   animator["parameters/conditions/Insert"] = true
   await get_tree().create_timer(0.1, false).timeout;
   animator["parameters/conditions/Insert"] = false
   slotData.amount += 1
