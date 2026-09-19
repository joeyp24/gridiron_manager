class_name UIFactory
extends RefCounted


static func label(text_value: String, variation: String = "BodyLabel") -> Label:
	var control := Label.new()
	control.text = text_value
	control.theme_type_variation = variation
	return control


static func wrapped_label(text_value: String, variation: String = "BodyLabel") -> Label:
	var control := label(text_value, variation)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control


static func button(text_value: String, variation: String = "Button") -> Button:
	var control := Button.new()
	control.text = text_value
	control.theme_type_variation = variation
	control.custom_minimum_size = Vector2(0, 42)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.focus_mode = Control.FOCUS_ALL
	return control


static func card(variation: String = "CardPanel") -> PanelContainer:
	var control := PanelContainer.new()
	control.theme_type_variation = variation
	return control


static func vbox(separation: int = 12) -> VBoxContainer:
	var control := VBoxContainer.new()
	control.add_theme_constant_override("separation", separation)
	return control


static func hbox(separation: int = 12) -> HBoxContainer:
	var control := HBoxContainer.new()
	control.add_theme_constant_override("separation", separation)
	return control


static func spacer(width: float = 0.0, height: float = 0.0) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(width, height)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


static func divider() -> HSeparator:
	var control := HSeparator.new()
	return control


static func badge(text_value: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	var badge_label := label(text_value, "BadgeLabel")
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	badge_label.add_theme_color_override("font_color", GridironTheme.INK if luminance > 0.52 else GridironTheme.TEXT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(badge_label)
	return panel


static func status_pill(text_value: String, color: Color = GridironTheme.ACCENT) -> PanelContainer:
	var panel := badge(text_value.to_upper(), Color(color, 0.16))
	var pill_label: Label = panel.get_child(0)
	pill_label.add_theme_color_override("font_color", color)
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(color, 0.42)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func metric_card(title: String, value: String, detail: String = "", accent: Color = GridironTheme.ACCENT) -> PanelContainer:
	var panel := card("MetricPanel")
	panel.custom_minimum_size = Vector2(150, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := vbox(3)
	panel.add_child(column)
	var title_label := label(title.to_upper(), "CaptionLabel")
	title_label.add_theme_color_override("font_color", Color(accent, 0.92))
	column.add_child(title_label)
	column.add_child(label(value, "MetricLabel"))
	if not detail.is_empty():
		column.add_child(wrapped_label(detail, "CaptionLabel"))
	return panel


static func page_heading(kicker: String, title: String, subtitle: String = "") -> VBoxContainer:
	var heading := vbox(4)
	if not kicker.is_empty():
		heading.add_child(label(kicker.to_upper(), "EyebrowLabel"))
	heading.add_child(label(title, "PageTitleLabel"))
	if not subtitle.is_empty():
		heading.add_child(wrapped_label(subtitle, "MutedLabel"))
	return heading


static func section_heading(title: String, detail: String = "") -> HBoxContainer:
	var row := hbox(10)
	var marker := ColorRect.new()
	marker.color = GridironTheme.ACCENT
	marker.custom_minimum_size = Vector2(3, 34 if not detail.is_empty() else 44)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var copy := vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(label(title, "SectionTitleLabel"))
	if not detail.is_empty():
		copy.add_child(wrapped_label(detail, "CaptionLabel"))
	row.add_child(copy)
	return row


static func empty_state(title: String, detail: String) -> PanelContainer:
	var panel := card("InsetPanel")
	var column := vbox(5)
	panel.add_child(column)
	column.add_child(label(title, "SectionTitleLabel"))
	column.add_child(wrapped_label(detail, "MutedLabel"))
	return panel


static func stat_bar(label_text: String, value: int, color: Color) -> VBoxContainer:
	var column := vbox(5)
	var heading := hbox(8)
	heading.add_child(label(label_text, "MutedLabel"))
	heading.add_child(spacer())
	heading.add_child(label(str(value), "BodyLabel"))
	column.add_child(heading)
	var bar := ProgressBar.new()
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	return column
