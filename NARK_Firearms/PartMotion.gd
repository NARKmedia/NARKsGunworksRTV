extends RefCounted

signal state_reached(kind: String,state: String)
var parts: Array = []
var poses: Dictionary = {}
var states: Dictionary = {}
var targets: Dictionary = {}
var blends: Dictionary = {}
var slide_locked = false
var bolt_phase = ""
var bolt_wait = 0.0
var bolt_empty = false
var recock = false

static func blend(a: Dictionary,b: Dictionary,weight: float) -> Dictionary:
 var t=clampf(weight,0,1)
 var p=Vector3(a.p[0],a.p[1],a.p[2]).lerp(Vector3(b.p[0],b.p[1],b.p[2]),t)
 var q=Quaternion(a.q[0],a.q[1],a.q[2],a.q[3]).normalized().slerp(Quaternion(b.q[0],b.q[1],b.q[2],b.q[3]).normalized(),t)
 var s=Vector3(a.s[0],a.s[1],a.s[2]).lerp(Vector3(b.s[0],b.s[1],b.s[2]),t)
 return {"p":[p.x,p.y,p.z],"q":[q.x,q.y,q.z,q.w],"s":[s.x,s.y,s.z]}
func definition(kind: String):
 for part in parts:
  if part.kind==kind:return part
 return null
func configure(definitions: Array):
 parts=definitions
 reset({})
func reset(initial: Dictionary):
 poses.clear();states.clear();targets.clear();blends.clear()
 recock=false;bolt_phase="";bolt_wait=0
 for part in parts:
  var state=str(initial.get(part.kind,{"hammer":"Cocked","slide":"Forward","selector":"Semi"}[part.kind]))
  if part.states.has(state):poses[part.kind]=part.states[state];states[part.kind]=state;targets[part.kind]=state
 slide_locked=states.get("slide","")=="Rear"
func request(kind: String,state: String,frames: float=0.0,explicit=true) -> bool:
 var part=definition(kind)
 if part==null or not part.states.has(state):return false
 var was_locked=slide_locked
 if explicit and kind=="slide":
  bolt_phase=""
  slide_locked=state=="Rear"
 if explicit and kind=="hammer":recock=false
 if targets.get(kind,"")==state:
  if kind=="slide" and was_locked!=slide_locked and states.get(kind,"")==state:state_reached.emit(kind,state)
  return false
 targets[kind]=state
 if frames<=0:
  poses[kind]=part.states[state];states[kind]=state;blends.erase(kind)
  state_reached.emit(kind,state)
 else:blends[kind]={"from":poses.get(kind,part.states[state]),"target":state,"age":0.0,"duration":frames/60.0}
 return true
func fire(empty: bool=false):
 fire_hammer()
 fire_bolt(empty)
func fire_hammer():
 var hammer=definition("hammer")
 if hammer!=null:
  request("hammer","Fired",hammer.get("fire_frames",1.0),false)
  states.hammer="Fired"
  recock=hammer.get("auto_cock",false)
func fire_bolt(empty: bool):
 var slide=definition("slide")
 if slide!=null:
  bolt_empty=empty and slide.get("hold_open",false)
  slide_locked=bolt_empty
  if slide.get("cycle",false) or bolt_empty:
   request("slide","Rear",slide.get("open_frames",2.0),false)
   bolt_phase="opening"
func advance(delta: float):
 if recock and states.get("hammer","")=="Fired" and not blends.has("hammer"):
  recock=false
  var hammer=definition("hammer")
  request("hammer","Cocked",hammer.get("fire_frames",1.0),false)
 var slide=definition("slide")
 if bolt_phase=="opening" and states.get("slide","")=="Rear" and not blends.has("slide"):
  bolt_phase="locked" if bolt_empty else "hold"
  bolt_wait=float(slide.get("hold_frames",1.0))/60.0
 elif bolt_phase=="hold":
  bolt_wait-=delta
  if bolt_wait<=0:
   request("slide","Forward",slide.get("close_frames",3.0),false)
   bolt_phase="closing"
 elif bolt_phase=="closing" and states.get("slide","")=="Forward" and not blends.has("slide"):bolt_phase=""
 for kind in blends.keys():
  var active=blends[kind]
  active.age+=delta
  var part=definition(kind)
  poses[kind]=blend(active.from,part.states[active.target],active.age/active.duration)
  if active.age+0.0000001>=active.duration:
   states[kind]=active.target
   blends.erase(kind)
   state_reached.emit(kind,active.target)
static func authored_at(events: Array,kind: String,frame: float) -> bool:
 var authored=false
 for event in events:
  if event.get("type","")!="part_state" or event.kind!=kind or float(event.frame)>frame:continue
  if event.action=="authored":authored=true
  elif event.action=="resume":authored=false
 return authored
func simulate(definitions: Array,events: Array,frame: float,initial: Dictionary):
 var motion=get_script().new()
 motion.configure(definitions);motion.reset(initial)
 var elapsed=0.0
 var ordered=events.duplicate()
 ordered.sort_custom(func(a,b):return float(a.frame)<float(b.frame))
 for event in ordered:
  if event.get("type","")!="part_state" or float(event.frame)>frame:continue
  motion.advance(maxf(0.0,float(event.frame)-elapsed)/60.0)
  elapsed=float(event.frame)
  if event.action=="set":motion.request(event.kind,event.state,float(event.get("duration",0)))
 motion.advance(maxf(0.0,frame-elapsed)/60.0)
 return motion
