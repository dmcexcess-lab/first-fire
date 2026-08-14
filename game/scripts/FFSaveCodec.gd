extends RefCounted
class_name FFSaveCodec

# File/JSON persistence mechanics live here. Game.gd still owns the save-state
# schema while Alpha is fluid; Beta can stabilize schema without rewriting IO.
static func exists(path: String) -> bool:
    return FileAccess.file_exists(path)

static func write_json(path: String, data: Dictionary) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data))
    return true

static func read_json(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    return JSON.parse_string(file.get_as_text())

static func is_compatible(parsed: Variant, schema_version: int) -> bool:
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var data: Dictionary = parsed
    return int(data.get("save_schema", -1)) == schema_version

static func invalidate(path: String) -> void:
    if not FileAccess.file_exists(path):
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
