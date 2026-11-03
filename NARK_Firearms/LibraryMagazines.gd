extends Node

var rig
var original:MeshInstance3D
var records:Array=[]
var current=""
var geometry_layers=0
var imported=""
var round_groups:Dictionary={}
var amount=-1
var phase=""
var reload_started=false
var reload_wait=0.0
var displayed_id=""
var displayed_amount=-1

func configure(owner_rig,model,items,imported_id):
 rig=owner_rig;original=rig.magazine;imported=imported_id
 if original==null:return
 geometry_layers=original.layers
 for item in items:
  if item.subtype!="Magazine":continue
  if item.id==imported:
   if item.get("material","")!="":original.material_override=load(item.material)
   var sk=original.get_node_or_null(original.skeleton) as Skeleton3D
   if item.has("rounds_scene") and sk!=null and original.skin!=null and original.skin.get_bind_count()==1:
    var bind_bone=original.skin.get_bind_bone(0)
    var bone_name=original.skin.get_bind_name(0)
    if bone_name!=&"":bind_bone=sk.find_bone(bone_name)
    if bind_bone>=0 and bind_bone<sk.get_bone_count():
     var anchor=BoneAttachment3D.new()
     anchor.name="Attachments"
     anchor.bone_idx=bind_bone
     sk.add_child(anchor)
     var group=add_rounds(anchor,item)
     if group!=null:group.transform=original.skin.get_bind_pose(0)
   continue
  var scene=load(item.scene) as PackedScene
  if scene==null:continue
  var node=scene.instantiate();model.add_child(node);node.hide()
  var sk=model.get_node_or_null(str(item.role)+"Rig/Skeleton3D") as Skeleton3D
  if sk==null:continue
  var bone=sk.find_bone(item.bone)
  if bone<0:continue
  var mesh=sk.get_node_or_null(str(item.role)) as MeshInstance3D
  var bind=Transform3D.IDENTITY
  if mesh!=null and mesh.skin!=null:
   for i in mesh.skin.get_bind_count():
    if mesh.skin.get_bind_bone(i)==bone or mesh.skin.get_bind_name(i)==item.bone:bind=mesh.skin.get_bind_pose(i);break
  var p=item.p;var r=item.r
  if item.has("rounds_scene"):
   var anchor=Node3D.new()
   anchor.name="Attachments"
   node.add_child(anchor)
   add_rounds(anchor,item)
  records.append({"id":item.id,"node":node,"sk":sk,"bone":bone,"bind":bind,"offset":Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2])*PI/180).scaled(Vector3.ONE*float(item.s)),Vector3(p[0],p[1],p[2]))})
 refresh()
 update_rounds(true)

func add_rounds(parent:Node3D,item) -> Node3D:
 var packed=load(item.rounds_scene) as PackedScene
 if packed==null:return null
 var group=packed.instantiate() as Node3D
 group.hide()
 parent.add_child(group)
 for mesh in group.find_children("*","GeometryInstance3D",true,false):
  mesh.layers=geometry_layers
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if group.get_child_count()==2:round_groups[item.id]=group
 return group

func start_transition(state:String):
 if round_groups.is_empty():return
 phase=state
 reload_started=false
 reload_wait=.35

func swap_rounds():
 if round_groups.is_empty():return
 refresh()
 update_rounds(true)

func update_rounds(read_count:bool):
 if round_groups.is_empty() or rig.slotData==null:return
 if read_count:amount=int(rig.slotData.amount)
 var selected=current if original.is_visible_in_tree() and round_groups.has(current) else ""
 if selected!=displayed_id:
  if displayed_id!="":round_groups[displayed_id].hide()
  displayed_id=selected
  displayed_amount=-1
  if displayed_id!="":round_groups[displayed_id].show()
 if displayed_id!="" and amount!=displayed_amount:
  var group=round_groups[displayed_id]
  group.get_child(0).visible=amount>1
  group.get_child(1).visible=amount>0
  displayed_amount=amount

func refresh():
 if rig.slotData==null:return
 var selected=""
 for nested in rig.slotData.nested:
  if nested!=null and nested.subtype=="Magazine":selected=nested.file;break
 current=selected
 original.layers=geometry_layers if current==imported or current=="" else 0
 for e in records:e.node.visible=e.id==current and original.visible
func _process(delta):
 if not is_instance_valid(original):return
 var state=rig.currentState
 if phase!="":
  if state==phase:reload_started=true
  elif reload_started:phase=""
  else:
   reload_wait-=delta
   if reload_wait<=0.0:phase=""
 if phase=="" and state in ["Idle","Magazine_Attach_Empty","Magazine_Attach_Tactical"]:refresh()
 if not round_groups.is_empty():update_rounds(phase=="" and state!="Magazine_Detach")
 for e in records:
  e.node.visible=e.id==current and original.visible
  if e.node.visible:e.node.global_transform=e.sk.global_transform*e.sk.get_bone_global_pose(e.bone)*e.bind*e.offset
