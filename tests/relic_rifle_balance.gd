extends SceneTree
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Description = preload("res://scripts/ui/item_description.gd")
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int = 30) -> void:
	game.new_match(1030)
	preload("res://tests/helpers/battle.gd").start(game,id)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	setup(game)
	var p = game.players[0]
	var q = game.players[1]
	assert(p.weapon().clip == 1 and p.weapon().reserve == 60)
	game.fire(0)
	assert(game.shots.size() == 1 and is_equal_approx(game.shots[0].damage,2.6))
	assert(p.weapon().clip == 0 and p.weapon().reserve == 60 and not p.can_fire())
	# Same single round is both the first and last; real reload enables another, not free ammo.
	setup(game)
	p.relics = [7,22,13,1]
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,3.65))
	p.start_reload()
	var duration: float = 1.25*(p.reload_duration/1.15)*.88
	assert(is_equal_approx(p.state.reload,duration))
	p.step(duration-.01,0,q,game.arena)
	assert(p.weapon().clip == 0 and not p.state.empty_casing_charge)
	p.step(.02,0,q,game.arena)
	assert(p.weapon().clip == 1 and p.weapon().reserve == 59 and p.state.empty_casing_charge)
	game.fire(0)
	assert(game.shots.size() == 3 and is_equal_approx(game.shots[-2].damage,3.65))
	assert(game.shots[-1].state.depth == 1 and is_equal_approx(game.shots[-1].damage,.5))
	assert(not p.state.empty_casing_charge)
	# A larger magazine separates first/last bonuses and costs reserve to fill the extra slot.
	setup(game)
	p.relics = [7,22,21]
	assert(p.definition().mag == 2 and p.weapon().clip == 1)
	p.start_reload()
	p.step(p.state.reload+.01,0,q,game.arena)
	assert(p.weapon().clip == 2 and p.weapon().reserve == 59)
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,3.25))
	p.state.shot = 0.0
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,3.0))
	# Last reserve round can complete a partial reload and still grant the next-shot pellet.
	setup(game,0)
	p.relics = [13]
	p.weapon().clip = 3
	p.weapon().reserve = 1
	p.start_reload()
	p.step(p.state.reload+.01,0,q,game.arena)
	assert(p.weapon().clip == 4 and p.weapon().reserve == 0 and p.state.empty_casing_charge)
	game.fire(0)
	assert(game.shots.size() == 2 and not p.state.empty_casing_charge)
	p.finish_reload()
	assert(not p.state.empty_casing_charge) # duplicate completion cannot mint a new charge
	# Actual recovery boosts the same weapon without switching, once even after two recoveries.
	setup(game,5)
	p.relics = [14]
	game.fire(0)
	var moon = game.shots[-1]
	moon.state.age = 1.0
	moon.state.pos = p.state.pos+Vector2(10,0)
	moon.step(.02,game.arena,q)
	assert(p.state.return_battery_charge)
	p.recover_projectile(5)
	p.state.shot = 0.0
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,1.45) and not p.state.return_battery_charge)
	p.state.shot = 0.0
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,1.0))
	# Switching to an echo gun must not duplicate the flat battery bonus on its derived shot.
	setup(game,19)
	p.relics = [14]
	p.state.return_battery_charge = true
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,1.0))
	assert(is_equal_approx(game.delayed_shots[-1].damage,.55))
	# Increased stock drives actual refill amounts and caps; clips are never refilled for free.
	setup(game,28)
	p.inventory = [p.new_weapon_entry(28)]
	p.state.gun = 0
	p.weapon().clip = 2
	p.weapon().reserve = 0
	assert(p.refill_ammo() == 20 and p.weapon().reserve == 20 and p.weapon().clip == 2)
	p.weapon().reserve = 47
	assert(p.refill_ammo() == 1 and p.weapon().reserve == 48)
	assert(p.refill_ammo() == 0)
	assert(Weapons.definition(37).stock == 18 and Weapons.definition(9).stock == 9)
	for id in Relics.SUPPORTED:
		var relic: Dictionary = Relics.definition(id)
		var description: String = Description.describe("relic",id,game.match_state,true)
		assert(relic.desc.length() < 70 and not str(relic.details).is_empty())
		assert(str(relic.desc) in description and "補足："+str(relic.details) in description)
		assert(("重複強化可能" in description) == Relics.stackable(id))
	print("PASS: single-round first/last/reload synergies, expanded magazine tradeoff, partial reserve reload, recovery without switch, refill quantity/caps and 35 readable descriptions")
	game.queue_free()
	quit()
