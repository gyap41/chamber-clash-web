extends SceneTree
# Builds the ashen foundry v2 stage materials (docs/art/production/ashen-foundry-v2) from the generated
# originals in assets/generated/ (never modified):
# - floor.png / wall-top.png: copies (the originals already tile within ~1 luminance point at the edges).
# - wall-face.png: cropped from mortar line y=6 to y=978 (exactly 8 courses) and scaled back to 1024 so
#   courses repeat vertically; the theme uses face_repeat_y so one course is ~38 world px.
# - edge.png: the 2px outer wall edge, a flat dark-brown ink colour (no generation).
# Run: Godot --headless --path . --script res://tools/build_stage_v2_materials.gd --quit-after 300
const SRC := "res://assets/generated/stage-v2-%s.png"
const OUT := "res://assets/stages/ashen-foundry-v2/"
const FACE_COURSES := Rect2i(0,6,1024,972)
const EDGE_INK := Color("2a1e16")

func load_png(name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SRC % name))
	image.convert(Image.FORMAT_RGBA8)
	return image

func save(image: Image, name: String) -> void:
	assert(image.save_png(ProjectSettings.globalize_path(OUT+name)) == OK)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	save(load_png("floor"),"floor.png")
	save(load_png("wall-top"),"wall-top.png")
	var face := load_png("wall-face").get_region(FACE_COURSES)
	face.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	save(face,"wall-face.png")
	var edge := Image.create(64,64,false,Image.FORMAT_RGBA8)
	edge.fill(EDGE_INK)
	save(edge,"edge.png")
	print("PASS: stage v2 materials")
	quit()
