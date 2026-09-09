extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	assert(title.get_node("Panel/Content/Heading").text == "CHAMBER CLASH")
	assert(title.get_node("Panel/Content/Start") is Button)
	# Pressing Start hands off straight into a CPU match (no Local/CPU choice on this screen —
	# see title.gd's comment): it should instantiate character_select.tscn with cpu_mode
	# preset to true, add it under the tree root, and remove/free itself.
	title.get_node("Panel/Content/Start").pressed.emit()
	assert(not is_instance_valid(title) or title.get_parent() == null)
	var found_select = null
	for child in root.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("character_select.gd"):
			found_select = child
	assert(found_select != null and found_select.cpu_mode == true)
	found_select.get_parent().remove_child(found_select)
	found_select.queue_free()
	print("PASS: title screen shows heading/start button, Start hands off to character_select.tscn with cpu_mode preset")
	quit()
