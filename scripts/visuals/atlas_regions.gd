extends RefCounted
# Callers cache their regions; this helper only creates the shared texture view.
static func region(sheet: Texture2D, rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = rect
	atlas.filter_clip = true
	return atlas

static func grid_cell(sheet: Texture2D, grid: Vector2i, index: int) -> AtlasTexture:
	var cell_size := sheet.get_size() / Vector2(grid)
	var coordinates := Vector2(index % grid.x, floori(float(index) / grid.x))
	return region(sheet, Rect2(coordinates * cell_size, cell_size))
