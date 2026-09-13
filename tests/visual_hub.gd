extends SceneTree
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Adapter = preload("res://tools/visual_hub/preview_adapter.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
var index := Index.new()
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	if not value: push_error(description); quit(1); assert(value,description)
func adapter(item: Dictionary, conditions: Dictionary):
	var node:=Adapter.new(); root.add_child(node); node.initialize(item,conditions); return node
func run() -> void:
	index.reload()
	check(index.errors.is_empty(),str(index.errors))
	for pair in [["キャラ",8],["武器",38],["レリック",35],["ステージ",2],["行動アイコン",3]]:
		check(index.enumerate("",pair[0]).size()==pair[1],str(pair))
	for item in index.records:
		check(item.issues.is_empty(),item.id+": "+str(item.issues))
		check(item.preview,"Preview supported: "+item.id)
	check(index.enumerate("weapon:20").size()==1,"Typed ID search")
	print("PASS: current catalog 8 / 38 / 35 / 2 / 3; dependencies and support diagnostics")
	index.install_game_snapshot()
	var conditions:=Store.defaults()
	for item in index.enumerate("","キャラ"):
		for action in ["待機","歩行","回避"]:
			for direction in range(4):
				conditions.action=action; conditions.aim=direction; conditions.movement=(direction+1)%4
				var node=adapter(item,conditions)
				check(node.players.size()==2,"Isolated actor initialization")
				for n in range(12): node.advance(1.0/60)
				check(node.players[0].char_id==int(item.definition.id),"Actual character")
				check(is_equal_approx(node.players[0].dodge_duration,.38 if int(item.definition.id)==0 else .26),"Dodge duration maintained")
				node.finish(); node.free()
	print("PASS: eight actual actor renderers / four aim and independent movement directions / three actions")
	conditions=Store.defaults(); conditions.action="連射"
	var max_wells:=0
	for item in index.enumerate("","武器"):
		var node=adapter(item,conditions)
		check(node.players[0].weapon().id==int(item.definition.id),"Weapon definition reused")
		var first_clip:int=node.players[0].weapon().clip
		for n in range(360):
			node.advance(1.0/60); max_wells=maxi(max_wells,node.wells.size())
		check(node.volley_counter>0,"Weapon fired: "+item.id)
		check(node.players[0].weapon().clip<=first_clip,"Real ammo")
		node.finish(); node.free()
		await process_frame
	check(max_wells>0,"Gravity derived effect reached")
	print("PASS: all 38 weapons, 6 seconds of real fire/projectile/hit/reload simulation; gravity reached")
	conditions.action="単発"
	var a=adapter(index.detail("weapon:37"),conditions)
	var b=adapter(index.detail("weapon:37"),conditions)
	for n in range(20): a.advance(conditions.dt); b.advance(conditions.dt)
	check(a.shots.size()==b.shots.size(),"Reproducible projectile count")
	for n in range(a.shots.size()): check(a.shots[n].state.pos.is_equal_approx(b.shots[n].state.pos),"Reproducible trajectories")
	a.players[0].weapon().clip=0
	check(b.players[0].weapon().clip>0,"Private actor inventory")
	a.finish(); a.free(); b.finish(); b.free()
	for item in index.enumerate("","ステージ"):
		var node=adapter(item,conditions)
		check(node.players.is_empty(),"Stage has no encounter actors")
		check(node.arena.get_node("Walls").get_child_count()==node.arena.runtime_definition.walls.size(),"Builder wall layout")
		check(node.arena.get_node("Spawns").get_child_count()==node.arena.runtime_definition.spawns.size(),"Builder spawn layout")
		node.finish(); node.free()
	print("PASS: deterministic independent previews and two stages without match participants")
	var fixture:=index.catalog.duplicate(true)
	var gun:Dictionary=fixture.guns[0].duplicate(true); gun.id=999; gun.name="Hub fixture"; fixture.guns.append(gun)
	var catalog_path:=Store.DIRECTORY+"/fixture-catalog.json"
	Store.save(catalog_path,fixture)
	index.reload(catalog_path)
	check(index.by_id.has("weapon:999") and not index.detail("weapon:999").game and not index.detail("weapon:999").preview,"Addition detected without fake game support")
	fixture.guns=fixture.guns.filter(func(g): return int(g.id)!=999)
	fixture.guns[0].erase("mag"); fixture.guns.append({"name":"invalid without id"})
	Store.save(catalog_path,fixture); index.reload(catalog_path)
	check(not index.by_id.has("weapon:999"),"Deletion detected")
	check(not index.detail("weapon:0").preview,"Missing required definition quarantined")
	check(not index.errors.is_empty(),"Malformed record reported without blocking list")
	var visual_fixture:=index.visuals.duplicate(true); visual_fixture.weapons["20"].body.texture="res://.local/visual-hub/missing.png"
	Store.save(Store.DIRECTORY+"/fixture-visuals.json",visual_fixture)
	index.reload("res://data/catalog.json",Store.DIRECTORY+"/fixture-visuals.json")
	check(not index.detail("weapon:20").assets and not index.detail("weapon:20").preview,"Missing image diagnosed")
	var unsupported=adapter(index.detail("weapon:20"),conditions)
	check(unsupported.players.is_empty() and not unsupported.failure.is_empty(),"Bad preview isolated")
	unsupported.finish(); unsupported.free()
	index.reload(); index.install_game_snapshot()
	conditions.compare=["character:0","character:1","weapon:10","weapon:37"]; conditions.seed=152; conditions.time=2.5; conditions.zoom=4.0
	Store.save(Store.DIRECTORY+"/test-conditions.json",{"conditions":conditions})
	var restored:=Store.normalize(Store.read(Store.DIRECTORY+"/test-conditions.json").conditions)
	check(restored.compare==conditions.compare and restored.seed==152 and restored.zoom==4.0 and restored.time==2.5,"Conditions roundtrip")
	check(index.enumerate("","武器").size()==38,"No dummy catalog modifications")
	check(Store.unique_path("png")!=Store.unique_path("png"),"No overwrite output names")
	print("PASS: additions/deletions/malformed data/missing assets/unsupported methods/reload and condition persistence")
	await process_frame
	quit()
