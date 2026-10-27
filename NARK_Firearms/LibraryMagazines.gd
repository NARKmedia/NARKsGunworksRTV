extends Node

var rig
var original:MeshInstance3D
var records:Array=[]
var current=""
var geometry_layers=0
var imported=""

func configure(owner_rig,model,items,imported_id):
 rig=owner_rig;original=rig.magazine;imported=imported_id
 if original==null:return
 geometry_layers=original.layers
 for item in items:
  if item.subtype!="Magazine":continue
  if item.id==imported:
   if item.get("material","")!="":original.material_override=load(item.material)
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
  records.append({"id":item.id,"node":node,"sk":sk,"bone":bone,"bind":bind,"offset":Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2])*PI/180).scaled(Vector3.ONE*float(item.s)),Vector3(p[0],p[1],p[2]))})
 refresh()
func refresh():
 if rig.slotData==null:return
 var selected=""
 for nested in rig.slotData.nested:
  if nested!=null and nested.subtype=="Magazine":selected=nested.file;break
 current=selected
 original.layers=geometry_layers if current==imported or current=="" else 0
 for e in records:e.node.visible=e.id==current and original.visible
func _process(_delta):
 if not is_instance_valid(original):return
 if rig.currentState in ["Idle","Magazine_Attach_Empty","Magazine_Attach_Tactical"]:refresh()
 for e in records:
  e.node.visible=e.id==current and original.visible
  if e.node.visible:e.node.global_transform=e.sk.global_transform*e.sk.get_bone_global_pose(e.bone)*e.bind*e.offset
