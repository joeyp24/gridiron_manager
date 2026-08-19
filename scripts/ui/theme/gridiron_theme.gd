class_name GridironTheme
extends RefCounted

const INK := Color("071319")
const BACKGROUND := Color("091920")
const SURFACE := Color("0d222b")
const SURFACE_RAISED := Color("122c36")
const SURFACE_SOFT := Color("173640")
const BORDER := Color("25454f")
const TEXT := Color("edf7f4")
const TEXT_MUTED := Color("8da9ad")
const ACCENT := Color("35e0a1")
const ACCENT_DARK := Color("163e35")
const WARM := Color("ffb457")
const DANGER := Color("ff6b72")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_MUTED, 0.48))
	theme.set_font_size("font_size", "Button", 15)
	theme.set_constant("outline_size", "Label", 0)

	_add_label_variations(theme)
	_add_panel_variations(theme)
	_add_button_variations(theme)
	_add_option_button(theme)
	_add_progress_bar(theme)
	_add_scroll_bar(theme)
	return theme


static func _add_label_variations(theme: Theme) -> void:
	_add_label(theme, "DisplayLabel", 42, TEXT)
	_add_label(theme, "PageTitleLabel", 30, TEXT)
	_add_label(theme, "SectionTitleLabel", 18, TEXT)
	_add_label(theme, "BodyLabel", 16, TEXT)
	_add_label(theme, "MutedLabel", 14, TEXT_MUTED)
	_add_label(theme, "CaptionLabel", 12, TEXT_MUTED)
	_add_label(theme, "EyebrowLabel", 12, ACCENT)
	_add_label(theme, "ScoreLabel", 42, TEXT)
	_add_label(theme, "MetricLabel", 24, TEXT)
	_add_label(theme, "BadgeLabel", 14, INK)


static func _add_label(theme: Theme, variation: String, font_size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _add_panel_variations(theme: Theme) -> void:
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _box(SURFACE, 12, BORDER, 1, 20))
	theme.set_type_variation("RaisedCardPanel", "PanelContainer")
	theme.set_stylebox("panel", "RaisedCardPanel", _box(SURFACE_RAISED, 12, BORDER, 1, 20))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _box(INK, 10, Color(INK, 0.0), 0, 14))
	theme.set_type_variation("TopBarPanel", "PanelContainer")
	theme.set_stylebox("panel", "TopBarPanel", _box(Color("0b2028"), 0, BORDER, 0, 0))
	theme.set_type_variation("AccentPanel", "PanelContainer")
	theme.set_stylebox("panel", "AccentPanel", _box(ACCENT_DARK, 12, Color(ACCENT, 0.42), 1, 18))


static func _add_button_variations(theme: Theme) -> void:
	_apply_button_styles(
		theme,
		"Button",
		_box(SURFACE_SOFT, 8, BORDER, 1, 12),
		_box(Color("204650"), 8, Color(ACCENT, 0.5), 1, 12),
		_box(ACCENT, 8, ACCENT, 1, 12)
	)

	theme.set_type_variation("PrimaryButton", "Button")
	_apply_button_styles(
		theme,
		"PrimaryButton",
		_box(ACCENT, 8, ACCENT, 1, 14),
		_box(Color("55e8b2"), 8, Color("55e8b2"), 1, 14),
		_box(Color("24bd85"), 8, Color("24bd85"), 1, 14)
	)
	theme.set_color("font_color", "PrimaryButton", INK)
	theme.set_color("font_hover_color", "PrimaryButton", INK)
	theme.set_color("font_pressed_color", "PrimaryButton", INK)

	theme.set_type_variation("SecondaryButton", "Button")
	_apply_button_styles(
		theme,
		"SecondaryButton",
		_box(Color(ACCENT, 0.08), 8, Color(ACCENT, 0.55), 1, 12),
		_box(Color(ACCENT, 0.14), 8, ACCENT, 1, 12),
		_box(Color(ACCENT, 0.22), 8, ACCENT, 1, 12)
	)

	theme.set_type_variation("GhostButton", "Button")
	_apply_button_styles(
		theme,
		"GhostButton",
		_box(Color.TRANSPARENT, 8, Color.TRANSPARENT, 0, 10),
		_box(Color(TEXT, 0.06), 8, Color.TRANSPARENT, 0, 10),
		_box(Color(TEXT, 0.10), 8, Color.TRANSPARENT, 0, 10)
	)
	theme.set_color("font_color", "GhostButton", TEXT_MUTED)
	theme.set_color("font_hover_color", "GhostButton", TEXT)

	theme.set_type_variation("TeamCardButton", "Button")
	_apply_button_styles(
		theme,
		"TeamCardButton",
		_box(SURFACE, 10, BORDER, 1, 16),
		_box(SURFACE_RAISED, 10, Color(ACCENT, 0.65), 1, 16),
		_box(ACCENT_DARK, 10, ACCENT, 2, 16)
	)
	theme.set_color("font_color", "TeamCardButton", TEXT)
	theme.set_color("font_pressed_color", "TeamCardButton", TEXT)
	theme.set_color("font_hover_color", "TeamCardButton", TEXT)


static func _apply_button_styles(
	theme: Theme,
	variation: String,
	normal: StyleBoxFlat,
	hover: StyleBoxFlat,
	pressed: StyleBoxFlat
) -> void:
	theme.set_stylebox("normal", variation, normal)
	theme.set_stylebox("hover", variation, hover)
	theme.set_stylebox("pressed", variation, pressed)
	theme.set_stylebox("focus", variation, hover)
	theme.set_stylebox("disabled", variation, _box(Color(SURFACE, 0.35), 8, Color(BORDER, 0.4), 1, 12))


static func _add_option_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "OptionButton", _box(SURFACE_SOFT, 8, BORDER, 1, 12))
	theme.set_stylebox("hover", "OptionButton", _box(Color("204650"), 8, Color(ACCENT, 0.55), 1, 12))
	theme.set_stylebox("pressed", "OptionButton", _box(ACCENT_DARK, 8, ACCENT, 1, 12))
	theme.set_stylebox("focus", "OptionButton", _box(SURFACE_SOFT, 8, ACCENT, 1, 12))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT)
	theme.set_constant("arrow_margin", "OptionButton", 12)


static func _add_progress_bar(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _box(INK, 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 4, Color.TRANSPARENT, 0, 0))
	theme.set_color("font_color", "ProgressBar", Color.TRANSPARENT)


static func _add_scroll_bar(theme: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("scroll", "VScrollBar", empty)
	theme.set_stylebox("grabber", "VScrollBar", _box(Color(BORDER, 0.75), 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(TEXT_MUTED, 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(ACCENT, 4, Color.TRANSPARENT, 0, 0))


static func _box(
	color: Color,
	radius: int,
	border_color: Color,
	border_width: int,
	padding: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	style.anti_aliasing = true
	return style
