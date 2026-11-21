extends RefCounted

const TAG="nark.gunworks.break_action.v1"
const EMPTY=0
const LIVE=1
const SPENT=2
var chambers:Array=[EMPTY,EMPTY]
var slot
var record:SlotData
var primary=0

func initialize(data,first:int):
 slot=data
 primary=first
 for entry in slot.storage:
  if entry!=null and entry.itemData==null and entry.state==TAG and entry.slot==str(slot.itemData.file):
   record=entry
   break
 var count=stock_count()
 if record!=null and record.amount>=0 and record.amount<=8:
  var bits=int(record.amount)
  chambers=[bits%3,int(bits/3.0)]
  reconcile()
 else:
  if count>=1:chambers[primary]=LIVE
  if count>=2:chambers[1-primary]=LIVE
  commit()

func stock_count() -> int:
 return clampi(int(slot.amount)+int(slot.chamber),0,2)

func reconcile() -> bool:
 var count=stock_count()
 if count==chambers.count(LIVE):return false
 # Vanilla UnloadWeapon clears both stock fields. Do not resurrect the rounds it returned.
 var remaining=count
 for index in [primary,1-primary]:
  if chambers[index]!=LIVE:continue
  if remaining>0:remaining-=1
  else:chambers[index]=EMPTY
 commit()
 return true

func commit():
 var entry=SlotData.new()
 entry.state=TAG
 entry.slot=str(slot.itemData.file)
 entry.amount=chambers[0]+3*chambers[1]
 var index=slot.storage.find(record) if record!=null else -1
 if index>=0:slot.storage[index]=entry
 else:slot.storage.append(entry)
 record=entry
 var count=chambers.count(LIVE)
 slot.chamber=count>0
 slot.amount=maxi(0,count-1)
 slot.casing=false

func set_chamber(index:int,value:int):
 if chambers[index]==value:return
 chambers[index]=value
 commit()

func load_target() -> int:
 for index in [primary,1-primary]:
  if chambers[index]!=LIVE:return index
 return -1

func firing_order(double_fire:bool) -> Array:
 var targets=[]
 for index in [primary,1-primary]:
  if chambers[index]!=LIVE:continue
  targets.append(index)
  if not double_fire:break
 return targets

func spend(targets:Array):
 for index in targets:chambers[index]=SPENT
 commit()
