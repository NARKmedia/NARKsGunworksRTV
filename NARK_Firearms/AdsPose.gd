extends RefCounted

static func native_basis(degrees:Vector3) -> Basis:
 var flip=Basis(Vector3.UP,PI)
 return flip*Basis.from_euler(degrees*PI/180.0)*flip.inverse()

static func preview_pose(position:Vector3,degrees:Vector3) -> Transform3D:
 return Transform3D(Basis(Vector3.UP,PI)*native_basis(degrees),position)
