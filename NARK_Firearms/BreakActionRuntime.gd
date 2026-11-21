extends "res://NARK_Firearms/WeaponRuntime.gd"

const Chambers=preload("BreakActionState.gd")
const Shells=preload("BreakShells.gd")
const OPEN=&"Break_Open"
const HOLD=&"Break_Hold"
const CLOSE=&"Break_Close"
const INSERTS=["Barrel1_Insert_Empty","Barrel1_Insert_Spent","Barrel2_Insert_Empty","Barrel2_Insert_Spent"]

var _ba_config:Dictionary
var _ba_state=Chambers.new()
var _ba_shells=Shells.new()
var _ba_playback:AnimationNodeStateMachinePlayback
var _ba_insert_clips:Dictionary={}
var _ba_effects:Array[Node3D]=[]
var _ba_active=-1
var _ba_step=0
var _ba_clip=""
var _ba_cues:Array=[]
var _ba_length=0.0
var _ba_open=false
var _ba_seen_clip=false
var _ba_ready=false

func _ready():
 super._ready()
 _ba_config=_vm_config.break_action
 cartridge=null
 var model=_vm_weapon.get_parent().get_parent()
 if not _ba_shells.setup(model):return
 _ba_state.initialize(slotData,int(_ba_config.get("primary",1))-1)
 if not _ba_config.get("double",false):slotData.mode=1
 gameData.firemode=1
 _ba_shells.show_states(_ba_state.chambers)
 for point in _vm_config.get("break_muzzles",[]):
  var anchor=Node3D.new()
  anchor.position=_vm_vec(point.p)
  anchor.rotation_degrees=_vm_vec(point.r)
  muzzle.get_parent().add_child(anchor)
  _ba_effects.append(anchor)
 if _vm_states!=null:
  for pair in [[OPEN,"Insert_Start"],[HOLD,"Insert_Idle"],[CLOSE,"Insert_End"]]:
   if _vm_states.overrides.has(pair[1]):_vm_states.overrides[str(pair[0])]=_vm_states.overrides[pair[1]]
 _ba_ready=_ba_setup_animation(model.get_node("AnimationPlayer"))
 if _ba_ready:animator.mixer_applied.connect(_ba_sync_shells)

func _ba_setup_animation(source:AnimationPlayer) -> bool:
 var inherited=animator.tree_root as AnimationNodeStateMachine
 if inherited==null:return false
 var graph=inherited.duplicate(true) as AnimationNodeStateMachine
 var lib=AnimationLibrary.new()
 for pair in [[OPEN,"Insert_Start",HOLD],[HOLD,"Insert_Idle",&""],[CLOSE,"Insert_End",&"Idle"]]:
  if not _ba_add_animation(graph,lib,source,pair[0],pair[1],pair[2]):return false
 for slot in INSERTS:
  if not source.has_animation(slot):continue
  if not _ba_add_animation(graph,lib,source,StringName(slot),slot,HOLD):return false
  _ba_insert_clips[slot]=source.get_animation(slot).length*60.0
 animator.active=false
 animations.add_animation_library(&"VosBreak",lib)
 var player_path=animator.anim_player
 animator.anim_player=NodePath("")
 animator.tree_root=graph
 animator.anim_player=player_path
 animator.active=true
 _ba_playback=animator.get("parameters/playback")
 return _ba_playback!=null

func _ba_add_animation(graph:AnimationNodeStateMachine,lib:AnimationLibrary,source:AnimationPlayer,name_key:StringName,slot:String,next:StringName) -> bool:
 if not source.has_animation(slot):return false
 var clip=source.get_animation(slot).duplicate(true) as Animation
 clip.loop_mode=Animation.LOOP_LINEAR if name_key==HOLD else Animation.LOOP_NONE
 for i in clip.get_track_count():
  clip.track_set_path(i,NodePath("VosModel/"+str(clip.track_get_path(i))))
 for event in _vm_config.events:
  if event.slot!=slot or event.type not in ["sound","part_state"]:continue
  if event.type=="part_state" and event.action!="set":continue
  var track=clip.add_track(Animation.TYPE_METHOD)
  clip.track_set_path(track,animations.get_parent().get_path_to(self))
  var call={"method":&"_vm_sound","args":[event.file]} if event.type=="sound" else {"method":&"_vm_break_part_action","args":[event.kind,event.state,float(event.get("duration",0)),str(name_key),str(event.kind)+":"+str(event.frame)]}
  clip.track_insert_key(track,minf(float(event.frame)/60.0,clip.length),call)
 var key=StringName(name_key)
 lib.add_animation(key,clip)
 var node=AnimationNodeAnimation.new()
 node.animation=StringName("VosBreak/"+str(key))
 graph.add_node(name_key,node)
 if next!=&"":
  # HOLD is added just after OPEN; link it once both exist.
  if graph.has_node(next):_ba_add_return(graph,name_key,next)
 if name_key==HOLD:_ba_add_return(graph,OPEN,HOLD)
 return true

func _ba_add_return(graph:AnimationNodeStateMachine,from:StringName,to:StringName):
 var transition=AnimationNodeStateMachineTransition.new()
 transition.switch_mode=AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
 transition.advance_mode=AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
 graph.add_transition(from,to,transition)

func _vm_break_part_action(kind:String,pose:String,frames:float,expected:String,cue:String):
 if _vm_states!=null:_vm_states.request(kind,pose,frames,expected,cue)

func _ba_sync_shells():
 if not _ba_ready or gameData.freeze or gameData.isCaching or gameData.isPlacing or gameData.isDrawing:return
 if _ba_active<0 and _ba_state.reconcile():_ba_shells.show_states(_ba_state.chambers)
 var node=_ba_playback.get_current_node()
 if _ba_active>=0:
  if node==StringName(_ba_clip):
   if not _ba_seen_clip:
    _ba_seen_clip=true
    _ba_shells.show_states(_ba_state.chambers,_ba_active)
   _ba_apply_cues(_ba_playback.get_current_play_position()*60.0)
  elif node==HOLD:
   if _ba_seen_clip:
    _ba_apply_cues(_ba_length+0.001)
    _ba_cancel_prop()
  else:_ba_cancel_prop()
 if _ba_open and node==&"Idle":
  _ba_open=false
  gameData.isInserting=false

func Insert():
 if not _ba_ready or gameData.isOccupied or gameData.isInspecting or gameData.isChecking or gameData.isReloading or gameData.isFiring or gameData.isClearing:return
 if slotData.state=="Jammed":return
 if Input.is_action_just_pressed("prepare"):
  if currentState==&"Idle" and not _ba_open:
   _ba_open=true
   gameData.isInserting=true
   PlayInsertStart()
   _ba_playback.start(OPEN)
  elif currentState==HOLD:
   PlayInsertEnd()
   _ba_playback.start(CLOSE)
  return
 if currentState==HOLD and Input.is_action_just_pressed("insert"):_ba_request_insert()

func _ba_request_insert():
 if _ba_active>=0:return
 var index=_ba_state.load_target()
 if index<0 or not _ba_has_ammo():return
 var kind="Spent" if _ba_state.chambers[index]==Chambers.SPENT else "Empty"
 var slot="Barrel%d_Insert_%s"%[index+1,kind]
 if not _ba_insert_clips.has(slot):return
 var cue_map=_ba_config.cues[slot]
 _ba_active=index
 _ba_clip=slot
 _ba_length=_ba_insert_clips[slot]
 _ba_step=0
 _ba_seen_clip=false
 _ba_cues=[]
 for cue in Shells.CUE_KEYS[kind]:_ba_cues.append([cue,float(cue_map[cue])])
 PlayInsert()
 _ba_playback.start(StringName(slot))

func _ba_has_ammo() -> bool:
 for item in interface.inventoryGrid.get_children():
  if item.slotData.itemData!=null and item.slotData.itemData.type=="Ammo" and item.slotData.itemData.file==data.ammo.file and item.slotData.amount>0:return true
 return false

func _ba_apply_cues(frame:float):
 while _ba_step<_ba_cues.size() and _ba_cues[_ba_step][1]<=frame+0.0001:
  match _ba_cues[_ba_step][0]:
   "clear":
    _ba_state.set_chamber(_ba_active,Chambers.EMPTY)
    _ba_update_inventory()
   "seat":
    if _ba_has_ammo() and interface.GetAmmo(data):
     _ba_state.set_chamber(_ba_active,Chambers.LIVE)
     _ba_update_inventory()
  _ba_step+=1

func _ba_cancel_prop():
 _ba_active=-1
 _ba_shells.show_states(_ba_state.chambers)

func Reload():
 if slotData.state=="Jammed":super.Reload()

func Firemode():
 if not _ba_ready or not _ba_config.get("double",false) or _ba_open or gameData.freeze or gameData.isDrawing or gameData.isCaching or gameData.isPlacing or gameData.isOccupied or gameData.isInspecting or gameData.isChecking or gameData.isClearing:return
 if not Input.is_action_just_pressed("firemode"):return
 slotData.mode=1 if slotData.mode==2 else 2
 gameData.firemode=1
 PlayFiremode()

func FireInput():
 if not _ba_ready or _ba_open or gameData.isOccupied or gameData.isChecking or gameData.isInspecting or gameData.isClearing or slotData.state=="Jammed":return
 if gameData.weaponPosition!=2 and not gameData.isAiming and not gameData.isCanted:return
 if Input.is_action_just_pressed("fire"):FireEvent()

func FireEvent():
 if not _ba_ready or _ba_open or currentState!=&"Idle" or slotData.state=="Jammed":return
 var targets=_ba_state.firing_order(_ba_config.get("double",false) and slotData.mode==2)
 if targets.is_empty() or fireTimer<fireRate or Malfunction():return
 for barrel in targets:
  for pellet in 6:
   Raycast(1.0)
   raycast.force_raycast_update()
 _ba_state.spend(targets)
 _ba_shells.show_states(_ba_state.chambers)
 if _ba_effects.size()==2:
  for barrel in targets:_ba_emit(_ba_effects[barrel])
 else:_ba_emit(muzzle)
 recoil.ApplyRecoil()
 if _vm_states!=null:_vm_states.on_shot()
 var double_audio=targets.size()==2 and _vm_config.audio.get("fire_auto","vanilla:")!="vanilla:"
 _vm_audio_key("suppressed" if activeMuzzle!=null else "fire_auto" if double_audio else "fire")
 PlayTail()
 if slotData.condition>0 and randi_range(0,100)<10:slotData.condition-=1
 if hammerLocked:hammerLocked=false
 _ba_update_inventory()
 fireTimer=0.0
 fireRate=maxf(float(data.fireRate),0.1)
 fireImpulse=0.1

func _ba_emit(point:Node3D):
 if activeMuzzle==null and not data.nativeSuppressor:
  rigManager.flash=true
  var flash=rigManager.muzzleFlash.instantiate()
  point.add_child(flash)
  flash.Emit(true,0.06)
 var smoke=rigManager.muzzleSmoke.instantiate()
 point.add_child(smoke)
 smoke.Emit(true,0.2)

func _ba_update_inventory():
 if weaponSlot!=null and weaponSlot.get_child_count()>0:weaponSlot.get_child(0).UpdateDetails()
