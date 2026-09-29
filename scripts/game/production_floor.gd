extends RefCounted
const Authored = preload("res://scripts/game/authored_floor.gd")
const Legacy = preload("res://scripts/game/exploration_floor.gd")
static func generate(seed_value: int) -> Dictionary:
 var floor=Authored.generate(seed_value)
 if not floor.errors.is_empty(): return floor
 var old=Legacy.generate(seed_value)
 if not old.errors.is_empty(): return old
 var boss_id=old.rooms.keys().filter(func(id):return old.rooms[id].role=="boss")[0]
 for id in floor.rooms:
  var meta: Dictionary=floor.rooms[id]
  if meta.role=="discovery": meta.role="treasure"
  if meta.role=="boss":
   var room=old.catalog[boss_id].duplicate(true)
   room.field.field_id=id
   room.doors[0].target_room=floor.catalog[id].doors[0].target_room
   room.doors[0].target_door="north"
   floor.catalog[id]=room
   meta.template_id=old.rooms[boss_id].template_id
  else:
   # Decorative coffers become actual interactive rewards, never duplicate fake chests.
   floor.catalog[id].field.placements.assign(floor.catalog[id].field.placements.filter(func(p):return p.placement_id not in ["back_relic","last_coffer","cell_hidden_coffer","secret_coffer"]))
 floor.production=true
 floor.errors=Legacy.validation_errors(floor)
 return floor
