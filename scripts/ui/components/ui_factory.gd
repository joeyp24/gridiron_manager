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
	control.custom_minimum_size = Vector2(0, 44)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	control.modulate = Color(1, 1, 1, 0.12)
	return control


static func badge(text_value: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var badge_label := label(text_value, "BadgeLabel")
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(badge_label)
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
