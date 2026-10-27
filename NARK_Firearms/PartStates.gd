extends SkeletonModifier3D

const Motion=preload("PartMotion.gd")
const META="nark_vosmodel_parts_v2"
var rig: Node
var parts: Array=[]
var indices: Dictionary={}
var overrides: Dictionary={}
var motion=Motion.new()
var pending_shot=false
var item_id=""
var active_slot=""
var fired_cues: Dictionary={}

func configure(source: Node,definitions: Array,events: Array):
 rig=source;parts=definitions
 item_id=str(rig.data.file)
 var initial={"hammer":"Cocked" if rig.hammerLocked else "Fired","slide":"Rear" if rig.slideLocked else "Forward","selector":"Auto" if rig.slotData.mode==2 else "Semi"}
 var saved=rig.slotData.get_meta(META,{})
 if saved.get("id","")==item_id:
  for kind in ["hammer","slide"]:
   if saved.has(kind):initial[kind]=saved[kind]
 motion.configure(parts);motion.reset(initial)
 motion.state_reached.connect(_commit)
 if motion.states.has("hammer"):rig.hammerLocked=motion.states.hammer=="Cocked"
 if motion.states.has("slide"):rig.slideLocked=motion.slide_locked
 for part in parts:indices[part.kind]=get_skeleton().find_bone(part.bone)
 for event in events:
  if event.get("type","")!="part_state":continue
  if not overrides.has(event.slot):overrides[event.slot]=[]
  overrides[event.slot].append(event)
 for events_for_clip in overrides.values():events_for_clip.sort_custom(func(a,b):return float(a.frame)<float(b.frame))
 _save()
func _save():
 var saved={"id":item_id}
 for part in parts:
  if part.kind=="selector":continue
  saved[part.kind]=("Rear" if motion.slide_locked else "Forward") if part.kind=="slide" else motion.states.get(part.kind,"Fired")
 rig.slotData.set_meta(META,saved)
func _commit(kind: String,state: String):
 if kind=="hammer":rig.hammerLocked=state=="Cocked"
 elif kind=="slide":rig.slideLocked=motion.slide_locked
 _save()
func refresh_slot() -> String:
 var playback=rig.animator.get("parameters/playback")
 var current=str(playback.get_current_node()) if playback!=null else ""
 if current!=active_slot:
  active_slot=current;fired_cues.clear()
 return current
func request(kind: String,state: String,frames: float,expected: String="",cue: String=""):
 var current=refresh_slot()
 if expected!="" and expected!=current:return
 if cue!="":
  if fired_cues.has(cue):return
  fired_cues[cue]=true
 motion.request(kind,state,frames)
func on_shot():
 motion.fire_hammer()
 rig.hammerLocked=false if motion.states.has("hammer") else rig.hammerLocked
 _save()
 pending_shot=true
func _physics_process(delta):
 if rig==null or rig.slotData==null:return
 var gd=rig.get("gameData")
 if gd!=null and gd.get("freeze")==true:return
 refresh_slot()
 if pending_shot:
  pending_shot=false
  motion.fire_bolt(not rig.slotData.chamber and rig.slotData.amount==0)
 var selector=motion.definition("selector")
 if selector!=null:motion.request("selector","Auto" if rig.slotData.mode==2 else "Semi",selector.get("switch_frames",3.0))
 motion.advance(delta)
func _process_modification():
 if rig==null or rig.slotData==null:return
 var playback=rig.animator.get("parameters/playback")
 if playback==null:return
 var slot=str(playback.get_current_node())
 var frame=float(playback.get_current_play_position())*60.0
 var events=overrides.get(slot,[])
 var sk=get_skeleton()
 for part in parts:
  var index=int(indices.get(part.kind,-1))
  if index<0 or Motion.authored_at(events,part.kind,frame):continue
  var pose=motion.poses.get(part.kind,{})
  if pose.is_empty():continue
  sk.set_bone_pose_position(index,Vector3(pose.p[0],pose.p[1],pose.p[2]))
  sk.set_bone_pose_rotation(index,Quaternion(pose.q[0],pose.q[1],pose.q[2],pose.q[3]).normalized())
  sk.set_bone_pose_scale(index,Vector3(pose.s[0],pose.s[1],pose.s[2]))
