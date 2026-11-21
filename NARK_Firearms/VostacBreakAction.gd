extends Node

enum CheckState { NONE, PENDING, ACTIVE }
var _rig
var _config
var _reload_handler
var _playback
var _hold_seconds=0.2
var _close_requested=false
var _check_state=CheckState.NONE
var _check_elapsed=0.0
var _check_released=false
var _check_seen=false

func configure(rig,config,reload_handler):
 _rig=rig;_config=config;_reload_handler=reload_handler
 _playback=rig.animator.get("parameters/playback")
 var constants=config.get_script().get_script_constant_map()
 _hold_seconds=maxf(0.01,float(constants.get("BUTTON_HOLD_MS",200))/1000.0)
 set_physics_process(false)

func _ready():set_physics_process(false)

func _busy() -> bool:
 var gd=_rig.gameData
 return _config.gated() or gd.isPlacing or gd.isDrawing or gd.isOccupied or gd.isInspecting or gd.isClearing or gd.isReloading

func _input(event):
 if _rig==null or event is InputEventMouseMotion:return
 # Releases must survive modal guards; a menu can swallow the key-up event.
 if event.is_action_released("prepare") and _rig._ba_open:
  _close_requested=true;set_physics_process(true)
 if event.is_action_released("reload"):
  _release_check()
 if _busy():return
 if event.is_action_pressed("prepare"):
  if _check_state!=CheckState.NONE or _rig.gameData.isChecking:return
  if _rig._ba_control_open():_close_requested=false;set_physics_process(true)
 elif event.is_action_pressed("fire"):
  if _rig._ba_open and not _close_requested:_rig._ba_control_insert()
 elif event.is_action_pressed("reload"):
  if _rig._ba_open or _rig.gameData.isChecking or _check_state!=CheckState.NONE:return
  if _playback.get_current_node()!=&"Idle":return
  _check_state=CheckState.PENDING;_check_elapsed=0.0;set_physics_process(true)

func _release_check():
 if _check_state==CheckState.PENDING:
  _check_state=CheckState.NONE
  # Tap R may clear a malfunction, but never runs the generic bolt reload.
  if not _busy() and _rig.slotData.state=="Jammed":_reload_handler._do_reload(false)
 elif _check_state==CheckState.ACTIVE:_check_released=true

func _begin_check():
 var graph=_rig.animator.tree_root as AnimationNodeStateMachine
 if graph==null or not graph.has_node(&"Ammo_Check"):
  _check_state=CheckState.NONE;return
 _check_state=CheckState.ACTIVE;_check_elapsed=0.0;_check_seen=false;_check_released=false
 _config.ammo_check_view=false
 _rig.gameData.isChecking=true;_rig.gameData.isFiring=false
 _rig.UpdateBullets();_rig.UpdateHUD();_rig.PlayAmmoCheck()
 _playback.start(&"Ammo_Check")

func _finish_check():
 if _check_state==CheckState.ACTIVE:
  _rig.gameData.isChecking=false;_config.ammo_check_view=false
 _check_state=CheckState.NONE;_check_elapsed=0.0;_check_released=false;_check_seen=false

func _physics_process(delta):
 if not is_instance_valid(_rig):set_physics_process(false);return
 if not Input.is_action_pressed("prepare") and _rig._ba_open:_close_requested=true
 if not Input.is_action_pressed("reload"):_release_check()
 if _busy():
  if _check_state==CheckState.PENDING:_check_state=CheckState.NONE
  return
 if _close_requested:
  if not _rig._ba_open:_close_requested=false
  elif _rig._ba_control_close():_close_requested=false
 if _check_state==CheckState.PENDING:
  _check_elapsed+=delta
  if _check_elapsed>=_hold_seconds:_begin_check()
 elif _check_state==CheckState.ACTIVE:
  _check_elapsed+=delta
  var state=_playback.get_current_node()
  if state==&"Ammo_Check":_check_seen=true
  if _check_elapsed>=0.5:_config.ammo_check_view=not _check_released
  # Use actual animation completion, including authored cues at the final frame.
  if (_check_seen and state!=&"Ammo_Check") or (not _check_seen and _check_elapsed>1.0):
   if _check_released:_finish_check()
 if not _rig._ba_open and not _close_requested and _check_state==CheckState.NONE:set_physics_process(false)

func _exit_tree():
 if is_instance_valid(_rig):
  _finish_check()
  if _rig._ba_open:_rig.gameData.isInserting=false
