extends Control

signal portal_requested
signal play_requested
signal simulate_requested
signal roster_requested
signal strategy_requested
signal front_office_requested
signal free_agency_requested
signal offseason_requested
signal save_requested

var _career: CareerSession
var _dashboard_grid: GridContainer


func setup(career: CareerSession) -> void:
	_career = career


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 720)
	scroll.add_child(page)

	var team := _career.user_team()
	var standing := _career.league.standing_for(team.id)
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.add_child(UIFactory.label(_career.league.data_source_label, "EyebrowLabel"))
	identity.add_child(UIFactory.label(team.display_name(), "PageTitleLabel"))
	var competition := "%s · %s" % [team.conference, team.division] if not team.division.is_empty() else "%s Conference" % team.conference
	identity.add_child(UIFactory.label("%s · %s" % [competition, _career.current_week_label()], "MutedLabel"))
	header.add_child(identity)
	header.add_child(UIFactory.spacer())
	header.add_child(_header_metric("RECORD", standing.record_label()))
	header.add_child(_header_metric("OVR", str(team.overall_rating())))
	header.add_child(_header_metric("ACTIVE", "%d/%d" % [team.active_roster_count(), team.players.size()]))
	header.add_child(_header_metric("CAP SPACE", PlayerContract.money_label(team.cap_space())))
	page.add_child(header)

	page.add_child(_build_next_game_card())

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	var portal := UIFactory.button("←  PORTAL", "GhostButton")
	portal.pressed.connect(func(): portal_requested.emit())
	actions.add_child(portal)
	var roster := UIFactory.button("DEPTH CHART", "SecondaryButton")
	roster.pressed.connect(func(): roster_requested.emit())
	actions.add_child(roster)
	var strategy := UIFactory.button("STRATEGY", "SecondaryButton")
	strategy.pressed.connect(func(): strategy_requested.emit())
	actions.add_child(strategy)
	var office := UIFactory.button("FRONT OFFICE", "SecondaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	actions.add_child(office)
	var market := UIFactory.button("FREE AGENCY", "SecondaryButton")
	market.pressed.connect(func(): free_agency_requested.emit())
	actions.add_child(market)
	var save := UIFactory.button("SAVE CAREER", "SecondaryButton")
	save.pressed.connect(func(): save_requested.emit())
	actions.add_child(save)
	var matchup := _career.current_matchup()
	var can_play := matchup != null and not matchup.played and not _career.league.is_offseason()
	var has_active_game := _career.active_simulator != null
	if _career.league.is_offseason():
		var offseason := UIFactory.button("OPEN OFFSEASON  ->", "PrimaryButton")
		offseason.pressed.connect(func(): offseason_requested.emit())
		actions.add_child(offseason)
	else:
		var play := UIFactory.button("RESUME GAME" if has_active_game else "PLAY GAME", "SecondaryButton")
		play.disabled = not can_play
		play.pressed.connect(func(): play_requested.emit())
		actions.add_child(play)
		var simulate := UIFactory.button(
			"SIMULATE CHAMPIONSHIP  ->" if _career.league.phase == LeagueState.PHASE_CHAMPIONSHIP else "SIMULATE WEEK  ->",
			"PrimaryButton"
		)
		simulate.disabled = has_active_game
		simulate.pressed.connect(func(): simulate_requested.emit())
		actions.add_child(simulate)
	page.add_child(actions)

	_dashboard_grid = GridContainer.new()
	_dashboard_grid.columns = 2
	_dashboard_grid.add_theme_constant_override("h_separation", 14)
	_dashboard_grid.add_theme_constant_override("v_separation", 14)
	_dashboard_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_dashboard_grid)
	_dashboard_grid.add_child(_build_standings_card())
	_dashboard_grid.add_child(_build_schedule_card())
	_dashboard_grid.add_child(_build_injuries_card())
	_dashboard_grid.add_child(_build_news_card())
	_dashboard_grid.add_child(_build_leaders_card())
	_dashboard_grid.add_child(_build_finance_card())
	_dashboard_grid.add_child(_build_team_status_card())


func _build_next_game_card() -> PanelContainer:
	var card := UIFactory.card("AccentPanel")
	var row := UIFactory.hbox(18)
	card.add_child(row)
	var league := _career.league
	if league.is_offseason():
		var record := league.latest_season_record()
		var champion := league.team_by_id(record.champion_team_id) if record != null else league.team_by_id(league.champion_team_id)
		var copy := UIFactory.vbox(3)
		copy.add_child(UIFactory.label(league.phase.to_upper(), "EyebrowLabel"))
		copy.add_child(UIFactory.label("%s are league champions" % champion.display_name(), "SectionTitleLabel"))
		copy.add_child(UIFactory.label("Open the offseason control room to prepare for %d." % (league.season_year + 1), "MutedLabel"))
		row.add_child(copy)
		row.add_child(UIFactory.spacer())
		row.add_child(UIFactory.badge(champion.abbreviation, champion.primary_color))
		return card
	var matchup := _career.current_matchup()
	if matchup == null:
		var copy := UIFactory.vbox(3)
		copy.add_child(UIFactory.label("CHAMPIONSHIP WEEK", "EyebrowLabel"))
		copy.add_child(UIFactory.label("Your season is complete", "SectionTitleLabel"))
		copy.add_child(UIFactory.label("Simulate the championship to crown the league winner.", "MutedLabel"))
		row.add_child(copy)
		return card
	var opponent := _career.next_opponent()
	var home_marker := "HOME" if matchup.home_team_id == league.user_team_id else "AWAY"
	var copy := UIFactory.vbox(3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label("NEXT MATCHUP · %s" % home_marker, "EyebrowLabel"))
	copy.add_child(UIFactory.label("vs %s" % opponent.display_name(), "SectionTitleLabel"))
	copy.add_child(UIFactory.label("%s · Opponent OVR %d" % [_career.current_week_label(), opponent.overall_rating()], "MutedLabel"))
	row.add_child(copy)
	row.add_child(UIFactory.badge(opponent.abbreviation, opponent.primary_color))
	var comparison := UIFactory.vbox(1)
	comparison.add_child(UIFactory.label("MATCHUP", "CaptionLabel"))
	comparison.add_child(UIFactory.label("%d — %d" % [_career.user_team().overall_rating(), opponent.overall_rating()], "MetricLabel"))
	row.add_child(comparison)
	return card


func _build_standings_card() -> PanelContainer:
	var card := _dashboard_card("LEAGUE TABLE", "Conference leaders qualify for the championship")
	var column: VBoxContainer = card.get_child(0)
	for conference in _career.league.conference_names():
		column.add_child(UIFactory.label(conference.to_upper(), "EyebrowLabel"))
		for index in range(_career.league.sorted_standings(conference).size()):
			var standing := _career.league.sorted_standings(conference)[index]
			column.add_child(_standing_row(standing, index == 0))
	return card


func _standing_row(standing: StandingData, leader: bool) -> PanelContainer:
	var team := _career.league.team_by_id(standing.team_id)
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	panel.add_child(row)
	row.add_child(UIFactory.label("◆" if leader else "·", "EyebrowLabel"))
	var name := UIFactory.label(team.display_name(), "BodyLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if team.id == _career.league.user_team_id:
		name.modulate = GridironTheme.ACCENT
	row.add_child(name)
	row.add_child(UIFactory.label(standing.record_label(), "BodyLabel"))
	row.add_child(UIFactory.label("%+d" % standing.point_differential(), "CaptionLabel"))
	return panel


func _build_schedule_card() -> PanelContainer:
	var card := _dashboard_card("WEEK SLATE", _career.current_week_label())
	var column: VBoxContainer = card.get_child(0)
	for matchup in _career.league.matchups_for_week(_career.league.current_week):
		var away := _career.league.team_by_id(matchup.away_team_id)
		var home := _career.league.team_by_id(matchup.home_team_id)
		var row_panel := UIFactory.card("InsetPanel")
		var row := UIFactory.hbox(8)
		row_panel.add_child(row)
		var teams := UIFactory.label("%s  @  %s" % [away.abbreviation, home.abbreviation], "BodyLabel")
		teams.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(teams)
		row.add_child(UIFactory.label(matchup.scoreline(), "BodyLabel"))
		column.add_child(row_panel)
	return card


func _build_injuries_card() -> PanelContainer:
	var injured := _career.user_team().injured_players()
	var card := _dashboard_card("MEDICAL CENTER", "%d current concern%s" % [injured.size(), "" if injured.size() == 1 else "s"])
	var column: VBoxContainer = card.get_child(0)
	if injured.is_empty():
		column.add_child(UIFactory.label("No players are currently unavailable through injury.", "MutedLabel"))
	else:
		for player in injured:
			var row := UIFactory.hbox(8)
			row.add_child(UIFactory.badge(player.position, _career.user_team().primary_color))
			var name := UIFactory.label(player.full_name, "BodyLabel")
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
			row.add_child(UIFactory.label(player.availability_label(), "CaptionLabel"))
			column.add_child(row)
	return card


func _build_news_card() -> PanelContainer:
	var card := _dashboard_card("CLUB WIRE", "Latest updates")
	var column: VBoxContainer = card.get_child(0)
	for index in range(mini(_career.league.news.size(), 5)):
		column.add_child(UIFactory.wrapped_label(_career.league.news[index], "MutedLabel"))
		if index < mini(_career.league.news.size(), 5) - 1:
			column.add_child(UIFactory.divider())
	return card


func _build_leaders_card() -> PanelContainer:
	var card := _dashboard_card("LEAGUE LEADERS", "Team performance through completed games")
	var column: VBoxContainer = card.get_child(0)
	var leaders := _career.league.team_leaders()
	column.add_child(_leader_row("SCORING", leaders["scoring"], "PF"))
	column.add_child(_leader_row("DEFENSE", leaders["defense"], "PA"))
	column.add_child(_leader_row("DIFFERENTIAL", leaders["differential"], "DIFF"))
	return card


func _leader_row(category: String, standing: StandingData, metric: String) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	panel.add_child(row)
	row.add_child(UIFactory.label(category, "CaptionLabel"))
	row.add_child(UIFactory.spacer())
	row.add_child(UIFactory.label(_career.league.team_by_id(standing.team_id).abbreviation, "BodyLabel"))
	var value := standing.points_for
	if metric == "PA":
		value = standing.points_against
	elif metric == "DIFF":
		value = standing.point_differential()
	row.add_child(UIFactory.label(str(value), "MetricLabel"))
	return panel


func _build_team_status_card() -> PanelContainer:
	var team := _career.user_team()
	var card := _dashboard_card("TEAM STATUS", "Lineup readiness and tactical identity")
	var column: VBoxContainer = card.get_child(0)
	column.add_child(UIFactory.stat_bar("OFFENSE", team.effective_offense_rating(), team.primary_color))
	column.add_child(UIFactory.stat_bar("DEFENSE", team.effective_defense_rating(), team.primary_color))
	column.add_child(UIFactory.stat_bar("SPECIAL TEAMS", team.effective_special_teams_rating(), team.primary_color))
	var status := UIFactory.hbox(10)
	status.add_child(UIFactory.label("Run rate %d%%" % roundi(team.run_tendency * 100.0), "CaptionLabel"))
	status.add_child(UIFactory.spacer())
	status.add_child(UIFactory.label("%s coverage" % team.coverage_preference, "CaptionLabel"))
	column.add_child(status)
	return card


func _build_finance_card() -> PanelContainer:
	var team := _career.user_team()
	var card := _dashboard_card("FRONT OFFICE", "Contracts, cap position, and market activity")
	var column: VBoxContainer = card.get_child(0)
	var cap_row := UIFactory.hbox(10)
	cap_row.add_child(_finance_metric("PAYROLL", PlayerContract.money_label(team.payroll())))
	cap_row.add_child(_finance_metric("SPACE", PlayerContract.money_label(team.cap_space())))
	cap_row.add_child(_finance_metric("DEAD CAP", PlayerContract.money_label(team.dead_cap)))
	column.add_child(cap_row)
	var latest := _career.league.recent_transactions(1)
	if latest.is_empty():
		column.add_child(UIFactory.label("No league transactions filed yet.", "MutedLabel"))
	else:
		var transaction: TransactionData = latest.front()
		column.add_child(UIFactory.wrapped_label("Latest: %s" % transaction.details, "MutedLabel"))
	return card


func _finance_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric.add_child(UIFactory.label(value, "BodyLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _dashboard_card(title: String, subtitle: String) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(360, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	column.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	return card


func _header_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size = Vector2(72, 0)
	var value_label := UIFactory.label(value, "MetricLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.add_child(value_label)
	var title_label := UIFactory.label(title, "CaptionLabel")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.add_child(title_label)
	return metric


func _apply_responsive_layout() -> void:
	if _dashboard_grid != null:
		_dashboard_grid.columns = 2 if size.x >= 900 else 1
