extends "res://Scripts/Pickup.gd"

var _initial:Dictionary={}
func UpdateAttachments():
 var container=get_node_or_null("Attachments")
 if container!=null:
  for node in container.get_children():
   if not _initial.has(node.name):_initial[node.name]=node.transform
   node.transform=_initial[node.name];node.hide()
 super.UpdateAttachments()
