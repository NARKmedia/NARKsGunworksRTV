extends RefCounted

const ROLES=["Ammo1","AmmoSpent1","Ammo2","AmmoSpent2"]
const CUE_KEYS={"Empty":["seat"],"Spent":["clear","seat"]}
var meshes:Array[MeshInstance3D]=[]

func setup(model:Node3D) -> bool:
 var found:Array[MeshInstance3D]=[]
 for role in ROLES:
  var mesh=model.get_node_or_null(role+"Rig/Skeleton3D/"+role) as MeshInstance3D
  if mesh==null:return false
  found.append(mesh)
 meshes=found
 return true

func show_states(states:Array,active:int=-1):
 for chamber in 2:
  for variant in 2:
   meshes[chamber*2+variant].visible=chamber==active or states[chamber]==variant+1
