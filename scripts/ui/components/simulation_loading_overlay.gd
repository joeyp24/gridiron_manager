class_name SimulationLoadingOverlay
extends Control

const SPINNER_FRAMES: Array[String] = ["●  ○  ○", "○  ●  ○", "○  ○  ●", "○  ●  ○"]

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _brand_mark: TextureRect
var _club_label: Label
var _spinner_label: Label
var _status_label: Label
var _detail_label: Label
var _percent_label: Label
var _progress_bar: ProgressBar
var _safety_note: Label
var _spinner_elapsed := 0.0
var _spinner_index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	visible = false
	set_process(false)


func begin_operation(title: String, subtitle: String, team: TeamData = null) -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle
	_club_label.text = team.abbreviation if team != null else "LEAGUE"
	_spinner_elapsed = 0.0
	_spinner_index = 0
	_spinner_label.text = SPINNER_FRAMES[0]
	update_progress(0.0, "PREPARING SIMULATION", "Loading the current league state and game-day rosters.")
	visible = true
	set_process(true)


func update_progress(ratio: float, status: String, detail: String) -> void:
	var progress := clampf(ratio, 0.0, 1.0)
	_progress_bar.value = progress * 100.0
	_percent_label.text = "%d%%" % roundi(progress * 100.0)
	_status_label.text = status
	_detail_label.text = detail


func finish_operation() -> void:
	visible = false
	set_process(false)


func progress_value() -> float:
	return _progress_bar.value


func status_text() -> String:
	return _status_label.text


func panel_minimum_width() -> float:
	return _panel.custom_minimum_size.x


func panel_width() -> float:
	return _panel.size.x


func _process(delta: float) -> void:
	_spinner_elapsed += delta
	if _spinner_elapsed < 0.18:
		return
	_spinner_elapsed = 0.0
	_spinner_index = (_spinner_index + 1) % SPINNER_FRAMES.size()
	_spinner_label.text = SPINNER_FRAMES[_spinner_index]


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(GridironTheme.BACKGROUND, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = UIFactory.card("RaisedCardPanel")
	_panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(_panel)

	var content := UIFactory.vbox(16)
	_panel.add_child(content)

	var accent_strip := ColorRect.new()
	accent_strip.color = GridironTheme.ACCENT
	accent_strip.custom_minimum_size = Vector2(0, 4)
	accent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(accent_strip)

	var header := UIFactory.hbox(14)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(header)
	_brand_mark = TextureRect.new()
	_brand_mark.texture = load("res://assets/branding/gridiron_mark.svg")
	_brand_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brand_mark.custom_minimum_size = Vector2(52, 52)
	header.add_child(_brand_mark)
	var heading := UIFactory.vbox(2)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_title_label = UIFactory.label("SIMULATING WEEK", "PageTitleLabel")
	_title_label.name = "OperationTitle"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_title_label)
	_subtitle_label = UIFactory.wrapped_label("Resolving every game across the league.", "MutedLabel")
	_subtitle_label.name = "OperationSubtitle"
	heading.add_child(_subtitle_label)
	_club_label = UIFactory.label("LEAGUE", "EyebrowLabel")
	_club_label.name = "ClubLabel"
	_club_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_club_label)

	var status_card := UIFactory.card("InsetPanel")
	content.add_child(status_card)
	var status_column := UIFactory.vbox(12)
	status_card.add_child(status_column)
	var status_row := UIFactory.hbox(12)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_column.add_child(status_row)
	_spinner_label = UIFactory.label(SPINNER_FRAMES[0], "EyebrowLabel")
	_spinner_label.name = "ActivityIndicator"
	status_row.add_child(_spinner_label)
	_status_label = UIFactory.wrapped_label("PREPARING SIMULATION", "SectionTitleLabel")
	_status_label.name = "StatusLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status_label)
	_percent_label = UIFactory.label("0%", "MetricLabel")
	_percent_label.name = "PercentLabel"
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(_percent_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "SimulationProgress"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	status_column.add_child(_progress_bar)
	_detail_label = UIFactory.wrapped_label("Loading the current league state and game-day rosters.", "MutedLabel")
	_detail_label.name = "ProgressDetail"
	_detail_label.custom_minimum_size = Vector2(0, 40)
	status_column.add_child(_detail_label)

	var footer := UIFactory.hbox(8)
	content.add_child(footer)
	footer.add_child(UIFactory.label("LIVE LEAGUE PROCESSING", "EyebrowLabel"))
	footer.add_child(UIFactory.spacer())
	_safety_note = UIFactory.label("Progress is saved when the week completes", "CaptionLabel")
	_safety_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_safety_note)


func _apply_responsive_layout() -> void:
	if _panel == null:
		return
	_panel.custom_minimum_size.x = clampf(size.x - 48.0, 280.0, 680.0)
	if _subtitle_label != null:
		_subtitle_label.visible = size.y >= 420.0
	var narrow := size.x < 480.0
	if _brand_mark != null:
		_brand_mark.visible = not narrow
	if _club_label != null:
		_club_label.visible = not narrow
	if _spinner_label != null:
		_spinner_label.visible = not narrow
	if _safety_note != null:
		_safety_note.visible = size.x >= 600.0
	if _title_label != null:
		_title_label.theme_type_variation = "SectionTitleLabel" if narrow else "PageTitleLabel"
