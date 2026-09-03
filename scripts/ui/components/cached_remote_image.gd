class_name CachedRemoteImage
extends PanelContainer

const CACHE_DIRECTORY := "user://gridiron_manager/image_cache"

var source_url := ""
var cache_identity := ""
var fallback_text := "?"
var accent_color := GridironTheme.BORDER
var image_size := Vector2(160, 180)

var _texture_rect: TextureRect
var _placeholder: Label
var _request: HTTPRequest


func setup(
	url: String,
	identity: String,
	placeholder: String,
	color: Color,
	minimum_size: Vector2 = Vector2(160, 180)
) -> void:
	source_url = url
	cache_identity = identity
	fallback_text = placeholder
	accent_color = color
	image_size = minimum_size


func _ready() -> void:
	custom_minimum_size = image_size
	clip_contents = true
	var background := StyleBoxFlat.new()
	background.bg_color = Color(accent_color, 0.12)
	background.border_color = Color(accent_color, 0.48)
	background.set_border_width_all(1)
	background.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", background)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_placeholder = UIFactory.label(fallback_text, "MetricLabel")
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.modulate = Color(accent_color, 0.86)
	_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placeholder)

	if source_url.is_empty() or not source_url.begins_with("https://") or DisplayServer.get_name() == "headless":
		return
	var cached := _cache_path()
	if FileAccess.file_exists(cached):
		var bytes := FileAccess.get_file_as_bytes(cached)
		if _apply_bytes(bytes):
			return
	_request = HTTPRequest.new()
	_request.timeout = 15.0
	_request.request_completed.connect(_download_completed)
	add_child(_request)
	var error := _request.request(source_url)
	if error != OK:
		_request.queue_free()


func _download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 and _apply_bytes(body):
		var absolute_directory := ProjectSettings.globalize_path(CACHE_DIRECTORY)
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
		if directory_error in [OK, ERR_ALREADY_EXISTS]:
			var file := FileAccess.open(_cache_path(), FileAccess.WRITE)
			if file != null:
				file.store_buffer(body)
				file.close()
	if _request != null:
		_request.queue_free()


func _apply_bytes(bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	var image := Image.new()
	var error := image.load_png_from_buffer(bytes)
	if error != OK:
		error = image.load_jpg_from_buffer(bytes)
	if error != OK:
		error = image.load_webp_from_buffer(bytes)
	if error != OK:
		return false
	_texture_rect.texture = ImageTexture.create_from_image(image)
	_placeholder.visible = false
	return true


func _cache_path() -> String:
	return "%s/%s.bin" % [CACHE_DIRECTORY, (cache_identity + "|" + source_url).sha256_text()]
