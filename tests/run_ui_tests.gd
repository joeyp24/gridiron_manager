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

	var career := CareerSession.new_career("nfl_buf", 882601, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var trade_scene: PackedScene = load("res://scenes/screens/trade_center_screen.tscn")
	var trade_screen := trade_scene.instantiate()
	trade_screen.setup(career)
	root.add_child(trade_screen)
	await process_frame
	trade_screen.size = Vector2(540, 900)
	trade_screen._apply_responsive_layout()
	_check(trade_screen._asset_grid.columns == 1, "Trade assets should stack into one column on a narrow display")
	_check(trade_screen._partners.size() == 31, "The Trade Center should expose every other club as a negotiation partner")
	_check(trade_screen._user_asset_buttons.size() >= 70 and trade_screen._partner_asset_buttons.size() >= 70, "The Trade Center should render full rosters and three years of draft capital")
	var user_pick: DraftPickData = TradeService.picks_owned_by(career.league, career.user_team().id).front()
	trade_screen._toggle_pick(true, true, user_pick.id)
	_check(trade_screen._user_pick_ids.has(user_pick.id) and trade_screen._offer_host.get_child_count() > 0, "Selecting a trade asset should refresh the live deal evaluation")
	trade_screen.size = Vector2(1440, 900)
	trade_screen._apply_responsive_layout()
	_check(trade_screen._asset_grid.columns == 3, "Trade assets and the deal room should use three columns on a wide display")
	trade_screen._select_partner(1)
	await process_frame
	_check(trade_screen._user_pick_ids.is_empty() and trade_screen._partner.id == trade_screen._partners[1].id, "Changing trade partners should clear stale offer assets")
	trade_screen.queue_free()
	if _failures.is_empty():
		print("PASS: %d assertions across responsive career-creation and Trade Center checks." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
