extends RefCounted
# Read-only adapter: components receive values, never an actor or progression object.
static func capture(player, controls_allowed: bool) -> Dictionary:
	var state: Dictionary = player.state
	var usable: bool = controls_allowed and state.hp > 0
	var weapons: Array = []
	for entry in player.inventory:
		var definition: Dictionary = player.resolved_definition(entry.id)
		weapons.append({"id":entry.id,"name":definition.name,"description":definition.desc,
			"clip":entry.clip,"reserve":entry.reserve,"infinite_reserve":player.infinite_reserve(entry.id),"mod_name":definition.get("mod_name","")})
	var dodge_duration: float = player.dodge_cooldown*(player.relic_value(24,"dodge_ratio") if 24 in player.relics else 1.0)
	var melee_duration: float = player.melee_cooldown*(player.relic_value(26,"melee_ratio") if 26 in player.relics else 1.0)
	return {"hp":state.hp,"max_hp":state.max_hp,"rally":player.rally_available(),
		"weapons":weapons,"selected":state.gun,"can_switch":usable,
		"weapon_name":player.definition().name,"reload":state.reload,
		"reload_duration":player.effective_reload_duration() if player.has_weapon() else 0.0,
		"actions":[
			{"wait":state.dodge,"duration":dodge_duration,"available":usable and state.dodge <= 0,
				"caption":"%.1f秒" % state.dodge if state.dodge > 0 else "回避"},
			{"wait":state.melee,"duration":melee_duration,"available":usable and state.melee <= 0 and state.reload <= 0 and state.roll <= 0,
				"caption":"%.1f秒" % state.melee if state.melee > 0 else "近接"},
			{"wait":0.0,"duration":1.0,"available":usable and state.pulses > 0,"caption":"パルス %d" % state.pulses}]}

static func refresh_health(bar, caption: Label, view: Dictionary) -> void:
	bar.refresh(view.hp,view.max_hp,view.rally)
	bar.tooltip_text = "黄色は反撃で回復できるHP。被ダメージの50%、各被弾から3秒以内に攻撃を当てて回収。"
	caption.text = "%.1f / %.0f" % [view.hp,view.max_hp] + ("  反撃回復 +%.1f" % view.rally if view.rally > 0 else "")
	caption.modulate = Color("ff9d83") if view.hp <= view.max_hp*.25 else Color.WHITE

static func refresh_actions(components: Array, view: Dictionary) -> void:
	for i in range(components.size()):
		var action: Dictionary = view.actions[i]
		components[i].refresh(action.wait,action.duration,action.available,action.caption)
