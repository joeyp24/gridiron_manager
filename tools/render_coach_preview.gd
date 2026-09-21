extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	# Requires the normal renderer, not --headless (which uses a dummy renderer).
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 1000)
	root.content_scale_size = Vector2i.ZERO
	var teams := SampleLeague.create_teams()
	var league := LeagueState.new(teams, teams[0].id, 9012)
	CoachProgressionService.initialize(league)
	var coach := league.user_team().coach
	coach.background = "offense"
	coach.xp = 1000
	for skill_id in ["offense_ground_1", "offense_ground_1", "offense_air_1", "offense_ground_2"]:
		CoachProgressionService.unlock(coach, skill_id)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	main._career = CareerSession.new(league)
	main._enable_career_navigation()
	main._show_coach_skills()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	var image := root.get_texture().get_image()
	var error := image.save_png("res://test-results/coach-wide.png")
	if error != OK:
		printerr("Screenshot failed: " + error_string(error))
		quit(1)
		return
	root.size = Vector2i(760, 1000)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	image.save_png("res://test-results/coach-compact.png")
	print("Coach previews captured.")
	quit()
