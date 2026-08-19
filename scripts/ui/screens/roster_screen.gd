extends Control

signal back_requested
signal roster_changed

var _career: CareerSession
var _team: TeamData
var _position_menu: OptionButton
var _player_list: VBoxContainer
var _selected_position := "QB"
var _show_attributes := true


func setup(career: CareerSession) -> void:
	_career = career
	_team = career.user_team()


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_rebuild_player_list()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 640)
	scroll.add_child(page)

	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(_team.abbreviation, _team.primary_color))
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label("DEPTH CHART", "PageTitleLabel"))
	copy.add_child(UIFactory.label("Set starters, order backups, and manage active status.", "MutedLabel"))
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var back := UIFactory.button("←  CAREER HUB", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	page.add_child(header)

	var status := UIFactory.card("RaisedCardPanel")
	page.add_child(status)
	var status_row := UIFactory.hbox(18)
	status.add_child(status_row)
	status_row.add_child(_metric("ACTIVE", "%d/%d" % [_team.active_roster_count(), _team.players.size()]))
	status_row.add_child(_metric("INJURED", str(_team.injured_players().size())))
	status_row.add_child(_metric("OFFENSE", str(_team.effective_offense_rating())))
	status_row.add_child(_metric("DEFENSE", str(_team.effective_defense_rating())))
	status_row.add_child(UIFactory.spacer())
	var helper := UIFactory.wrapped_label("The highest available player in each position group starts. Fatigue and injuries affect effective ratings.", "CaptionLabel")
	helper.custom_minimum_size = Vector2(300, 0)
	status_row.add_child(helper)

	var toolbar := UIFactory.hbox(10)
	toolbar.add_child(UIFactory.label("POSITION GROUP", "EyebrowLabel"))
	_position_menu = OptionButton.new()
	_position_menu.custom_minimum_size = Vector2(150, 44)
	for position_name in TeamData.ROSTER_POSITIONS:
		_position_menu.add_item(position_name)
	_position_menu.item_selected.connect(_select_position)
	toolbar.add_child(_position_menu)
	toolbar.add_child(UIFactory.spacer())
	toolbar.add_child(UIFactory.label("Use the arrows to change priority", "CaptionLabel"))
	page.add_child(toolbar)

	var list_card := UIFactory.card()
	list_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(list_card)
	_player_list = UIFactory.vbox(6)
	list_card.add_child(_player_list)


func _select_position(index: int) -> void:
	_selected_position = TeamData.ROSTER_POSITIONS[index]
	_rebuild_player_list()


func _rebuild_player_list() -> void:
	if _player_list == null:
		return
	for child in _player_list.get_children():
		_player_list.remove_child(child)
		child.queue_free()
	var players := _team.depth_players(_selected_position)
	var starter := _team.player_at(_selected_position)
	var heading := UIFactory.hbox(8)
	heading.add_child(UIFactory.label("%s ROOM" % _selected_position, "SectionTitleLabel"))
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.label("%d PLAYERS" % players.size(), "CaptionLabel"))
	_player_list.add_child(heading)
	for index in range(players.size()):
		_player_list.add_child(_player_row(players[index], index, starter))


func _player_row(player: PlayerData, index: int, starter: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(10)
	panel.add_child(row)
	var role := "STARTER" if starter != null and player.id == starter.id else ("BACKUP %d" % index)
	row.add_child(UIFactory.badge(role, _team.primary_color if role == "STARTER" else GridironTheme.BORDER))
	var identity := UIFactory.vbox(1)
	identity.custom_minimum_size = Vector2(190, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(player.full_name, "BodyLabel"))
	identity.add_child(UIFactory.label("Age %d · %s" % [player.age, player.availability_label()], "CaptionLabel"))
	row.add_child(identity)
	if _show_attributes:
		row.add_child(_small_metric("SPD", player.speed))
		row.add_child(_small_metric("PWR", player.power))
		row.add_child(_small_metric("TEC", player.technique))
		row.add_child(_small_metric("AWR", player.awareness))
	row.add_child(_small_metric("OVR", player.effective_overall()))
	var up := UIFactory.button("↑", "GhostButton")
	up.custom_minimum_size = Vector2(40, 40)
	up.disabled = index == 0
	up.pressed.connect(_move_player.bind(player.id, -1))
	row.add_child(up)
	var down := UIFactory.button("↓", "GhostButton")
	down.custom_minimum_size = Vector2(40, 40)
	down.disabled = index == _team.depth_players(_selected_position).size() - 1
	down.pressed.connect(_move_player.bind(player.id, 1))
	row.add_child(down)
	var active := UIFactory.button("ACTIVE" if player.is_active else "INACTIVE", "SecondaryButton")
	active.custom_minimum_size = Vector2(96, 40)
	active.disabled = player.injury_weeks > 0
	active.pressed.connect(_toggle_active.bind(player.id))
	row.add_child(active)
	return panel


func _move_player(player_id: String, direction: int) -> void:
	if _team.move_on_depth_chart(_selected_position, player_id, direction):
		roster_changed.emit()
		_rebuild_player_list()


func _toggle_active(player_id: String) -> void:
	var player := _team.player_by_id(player_id)
	if player == null or player.injury_weeks > 0:
		return
	player.is_active = not player.is_active
	roster_changed.emit()
	_rebuild_player_list()


func _small_metric(label_text: String, value: int) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size = Vector2(48, 0)
	var value_label := UIFactory.label(str(value), "BodyLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metric.add_child(value_label)
	var caption := UIFactory.label(label_text, "CaptionLabel")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metric.add_child(caption)
	return metric


func _metric(label_text: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size = Vector2(80, 0)
	metric.add_child(UIFactory.label(value, "MetricLabel"))
	metric.add_child(UIFactory.label(label_text, "CaptionLabel"))
	return metric


func _apply_responsive_layout() -> void:
	var should_show := size.x >= 960
	if should_show != _show_attributes:
		_show_attributes = should_show
		_rebuild_player_list()
