extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/screens/career_select.tscn")
	var screen := packed.instantiate()
	screen.setup()
	root.add_child(screen)
	await process_frame

	screen.size = Vector2(540, 900)
	screen._apply_responsive_layout()
	screen._select_source(0)
	await process_frame
	_check(screen._team_grid.columns == 1, "Career clubs should reflow to one column on a narrow display")
	_check(screen._team_buttons.size() == 32, "The real-data source should render all 32 selectable club cards")
	_check(screen._selected_source_id == LeagueCatalog.SOURCE_NFLVERSE_FULL, "The complete league database should be active")
	_check(screen._details_host.get_child_count() > 0, "The selected real-data club should render its profile")

	screen.size = Vector2(1440, 900)
	screen._apply_responsive_layout()
	await process_frame
	_check(screen._team_grid.columns == 4, "Career clubs should use four columns on a wide display")
	screen._select_source(0)
	await process_frame
	_check(screen._selected_source_id == LeagueCatalog.SOURCE_NFLVERSE_FULL, "The full league should remain the only new-career database")
	_check(screen._team_buttons.size() == 32, "Refreshing the database should replace rather than duplicate club cards")

	screen.queue_free()
	if _failures.is_empty():
		print("PASS: %d assertions across responsive career-creation checks." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
