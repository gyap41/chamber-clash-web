extends RefCounted
# Portable, value-only model. No live Nodes or shared game Resources in records.
static func make(id: String, title: String, kind: String, status: String = "現行") -> Dictionary:
	return {"id":id,"name":title,"kind":kind,"status":status,"definition":{},"image":"","references":[],"users":[],"related":[],"issues":[],"defined":false,"assets":false,"game":false,"preview":false,"method":"image"}
static func add_reference(item: Dictionary, path: String, relation: String, reason: String) -> void:
	if path.is_empty(): return
	for old in item.references:
		if old.path == path and old.relation == relation: return
	item.references.append({"path":path,"relation":relation,"reason":reason})
	if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
		item.issues.append("パス欠落: " + path)
static func matches(item: Dictionary, query: String, kind: String, status: String) -> bool:
	return (kind == "すべて" or item.kind == kind) and (status == "すべて" or item.status == status or (status == "要確認" and not item.issues.is_empty())) and (query.is_empty() or (item.name+" "+item.id+" "+item.status+" "+str(item.definition.get("type",""))).to_lower().contains(query.to_lower()))
