extends SkeletonModifier3D

var _poses:Array=[]
var _fitted=false

func configure(definitions:Array,fitted:bool):
 _poses.clear()
 var skeleton=get_skeleton()
 for part in definitions:
  var index=skeleton.find_bone(part.bone)
  if index<0:continue
  _poses.append({"index":index,"normal":rotation(part.normal),"folded":rotation(part.folded)})
 set_optic(fitted)

static func rotation(values:Array) -> Quaternion:
 return Quaternion(values[0],values[1],values[2],values[3]).normalized()

func set_optic(fitted:bool):
 _fitted=fitted

func _process_modification():
 var skeleton=get_skeleton()
 for part in _poses:
  skeleton.set_bone_pose_rotation(part.index,part.folded if _fitted else part.normal)
