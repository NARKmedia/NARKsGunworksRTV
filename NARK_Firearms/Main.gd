extends Node

var _textures:Dictionary={}
var _materials:Array[ShaderMaterial]=[]
var _legacy

func _ready():
 var lib=Engine.get_meta("RTVModLib",null)
 if lib==null or not lib.has_method("register"):return
 if lib.has_signal("frameworks_ready") and lib.get("_is_ready")==false:await lib.frameworks_ready
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://NARK_Firearms/Manifest.json"))
 for entry in manifest.materials:
  var material=load(entry.path) as ShaderMaterial
  if material==null:continue
  _materials.append(material)
  for key in ["albedo","normal"]:
   if entry.get(key,"")=="":continue
   var tex=texture(entry[key],key=="normal")
   if tex!=null:material.set_shader_parameter(key,tex)
 for entry in manifest.items:
  var item=load(entry.definition)
  lib.register("items",entry.id,item)
  lib.register("scenes",entry.id,load(entry.world))
  if entry.get("rig","")!="":lib.register("scenes",entry.id+"_Rig",load(entry.rig))
  lib.register("loot",entry.id+"_Master",{"item":item,"table":"LT_Master"})
 if manifest.get("legacy_script","")!="":
  _legacy=load(manifest.legacy_script).new();add_child(_legacy);_legacy._lib=lib;_legacy.configure_magazines()

func texture(path:String,normal:bool) -> Texture2D:
 if _textures.has(path):return _textures[path]
 if not FileAccess.file_exists(path):return null
 var image=Image.new()
 if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
 image.generate_mipmaps(normal)
 var t=ImageTexture.create_from_image(image);_textures[path]=t;return t
