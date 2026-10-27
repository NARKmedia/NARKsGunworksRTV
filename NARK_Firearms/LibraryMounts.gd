extends SkeletonModifier3D

var _rig
var _cache:Array=[]

func configure(rig,model,items):
 _rig=rig
 if rig.attachments!=null:rig.attachments.hide()
 var weapon=model.get_node("WeaponRig/Skeleton3D") as Skeleton3D
 var mesh=weapon.get_node("Weapon") as MeshInstance3D
 var anchor=BoneAttachment3D.new();anchor.bone_idx=0;anchor.bone_name=weapon.get_bone_name(0);weapon.add_child(anchor)
 var reference=Node3D.new();anchor.add_child(reference);reference.transform=mesh.skin.get_bind_pose(0)
 var container=Node3D.new();container.name="GunworksAttachments";reference.add_child(container);rig.attachments=container
 for item in items:
  if item.subtype=="Magazine":continue
  var scene=load(item.scene) as PackedScene
  if scene==null:continue
  var node=scene.instantiate();node.name=item.id;container.add_child(node);node.owner=rig;node.hide()
  var sk=model.get_node_or_null(str(item.get("role","Weapon"))+"Rig/Skeleton3D") as Skeleton3D
  if sk==null:continue
  var bone=sk.find_bone(item.bone)
  if bone<0:continue
  var skmesh=sk.get_node_or_null(str(item.get("role","Weapon"))) as MeshInstance3D
  var bind=Transform3D.IDENTITY
  if skmesh!=null and skmesh.skin!=null:
   for index in skmesh.skin.get_bind_count():
    if skmesh.skin.get_bind_bone(index)==bone or skmesh.skin.get_bind_name(index)==item.bone:bind=skmesh.skin.get_bind_pose(index);break
  var offset=Transform3D(Basis.from_euler(vec(item.r)*PI/180).scaled(Vector3.ONE*float(item.get("s",1))),vec(item.p))
  _cache.append({"sk":sk,"bone":bone,"bind":bind,"offset":offset,"node":node,"subtype":item.subtype})
 update_nodes()
 var handling=rig.get_node("Handling")
 var aim_basis=handling._vm_ads_basis() if handling.has_method("_vm_ads_basis") else Basis.IDENTITY
 for entry in _cache:
  if entry.subtype=="Optic":
   entry.node.defaultPosition=entry.node.position.z
   var pose=model.global_transform.affine_inverse()*entry.node.global_transform
   pose=Transform3D(aim_basis,Vector3.ZERO)*pose
   var secondary=entry.node.get("secondary")
   _rig._vm_optic_aim[str(entry.node.name)]={"height":pose.origin.y,"secondary_height":(pose.basis*secondary.position).y if secondary!=null else 0.0}

func vec(a):return Vector3(a[0],a[1],a[2])
func _process_modification():update_nodes()
func update_nodes():
 for e in _cache:
  e.node.global_transform=e.sk.global_transform*e.sk.get_bone_global_pose(e.bone)*e.bind*e.offset
  if e.subtype=="Optic" and _rig.slotData!=null:e.node.position.z+=_rig.slotData.position
