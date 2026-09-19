class_name GridironTheme
extends RefCounted

# Broadcast/front-office palette. Club colors remain the strongest local
# accent while these tokens keep every screen readable and consistent.
const INK := Color("070b10")
const BACKGROUND := Color("0a1017")
const BACKGROUND_SOFT := Color("0d151f")
const SURFACE := Color("111b26")
const SURFACE_RAISED := Color("172432")
const SURFACE_SOFT := Color("1d2d3d")
const SURFACE_HOVER := Color("233748")
const BORDER := Color("2a3d50")
const BORDER_SOFT := Color("1b2a38")
const TEXT := Color("f4f7fa")
const TEXT_MUTED := Color("94a4b5")
const TEXT_FAINT := Color("627487")
const ACCENT := Color("55d8a5")
const ACCENT_BRIGHT := Color("78e7bd")
const ACCENT_DARK := Color("123d34")
const BLUE := Color("62a8ff")
const BLUE_DARK := Color("172f4a")
const WARM := Color("f0b45b")
const DANGER := Color("f0717c")
const SUCCESS := Color("55d8a5")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_MUTED, 0.42))
	theme.set_font_size("font_size", "Button", 14)
	theme.set_constant("outline_size", "Label", 0)

	_add_label_variations(theme)
	_add_panel_variations(theme)
	_add_button_variations(theme)
	_add_option_button(theme)
	_add_line_edit(theme)
	_add_check_button(theme)
	_add_popup_menu(theme)
	_add_progress_bar(theme)
	_add_scroll_bar(theme)
	_add_separators(theme)
	return theme


static func _add_label_variations(theme: Theme) -> void:
	_add_label(theme, "DisplayLabel", 46, TEXT)
	_add_label(theme, "PageTitleLabel", 31, TEXT)
	_add_label(theme, "SectionTitleLabel", 18, TEXT)
	_add_label(theme, "BodyLabel", 15, TEXT)
	_add_label(theme, "MutedLabel", 14, TEXT_MUTED)
	_add_label(theme, "CaptionLabel", 12, TEXT_MUTED)
	_add_label(theme, "EyebrowLabel", 11, ACCENT)
	_add_label(theme, "ScoreLabel", 44, TEXT)
	_add_label(theme, "MetricLabel", 25, TEXT)
	_add_label(theme, "HeroMetricLabel", 34, TEXT)
	_add_label(theme, "BadgeLabel", 11, INK)
	_add_label(theme, "NavSectionLabel", 10, TEXT_FAINT)
	_add_label(theme, "TableHeaderLabel", 11, TEXT_MUTED)
	_add_label(theme, "PositiveLabel", 14, SUCCESS)
	_add_label(theme, "WarningLabel", 14, WARM)
	_add_label(theme, "DangerLabel", 14, DANGER)


static func _add_label(theme: Theme, variation: String, font_size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _add_panel_variations(theme: Theme) -> void:
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _box(SURFACE, 10, BORDER_SOFT, 1, 18, true))
	theme.set_type_variation("RaisedCardPanel", "PanelContainer")
	theme.set_stylebox("panel", "RaisedCardPanel", _box(SURFACE_RAISED, 10, BORDER, 1, 18, true))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _box(BACKGROUND_SOFT, 7, BORDER_SOFT, 1, 12))
	theme.set_type_variation("TopBarPanel", "PanelContainer")
	theme.set_stylebox("panel", "TopBarPanel", _box(Color("0d1620"), 0, BORDER_SOFT, 0, 0))
	theme.set_type_variation("SidebarPanel", "PanelContainer")
	theme.set_stylebox("panel", "SidebarPanel", _box(Color("0b121a"), 0, BORDER_SOFT, 0, 0))
	theme.set_type_variation("AccentPanel", "PanelContainer")
	theme.set_stylebox("panel", "AccentPanel", _box(Color("12352f"), 10, Color(ACCENT, 0.36), 1, 20, true))
	theme.set_type_variation("HeroPanel", "PanelContainer")
	theme.set_stylebox("panel", "HeroPanel", _box(Color("142837"), 12, Color(BLUE, 0.25), 1, 24, true))
	theme.set_type_variation("MetricPanel", "PanelContainer")
	theme.set_stylebox("panel", "MetricPanel", _box(Color("101b26"), 8, BORDER_SOFT, 1, 14))
	theme.set_type_variation("TableHeaderPanel", "PanelContainer")
	theme.set_stylebox("panel", "TableHeaderPanel", _box(Color("162331"), 6, BORDER_SOFT, 1, 10))
	theme.set_type_variation("DangerPanel", "PanelContainer")
	theme.set_stylebox("panel", "DangerPanel", _box(Color("351c25"), 8, Color(DANGER, 0.45), 1, 16))


static func _add_button_variations(theme: Theme) -> void:
	_apply_button_styles(theme, "Button", _box(SURFACE_SOFT, 7, BORDER, 1, 12), _box(SURFACE_HOVER, 7, Color(ACCENT, 0.48), 1, 12), _box(Color("294454"), 7, ACCENT, 1, 12))

	theme.set_type_variation("PrimaryButton", "Button")
	_apply_button_styles(theme, "PrimaryButton", _box(ACCENT, 7, ACCENT, 1, 14, true), _box(ACCENT_BRIGHT, 7, ACCENT_BRIGHT, 1, 14, true), _box(Color("35b985"), 7, Color("35b985"), 1, 14))
	theme.set_color("font_color", "PrimaryButton", INK)
	theme.set_color("font_hover_color", "PrimaryButton", INK)
	theme.set_color("font_pressed_color", "PrimaryButton", INK)

	theme.set_type_variation("SecondaryButton", "Button")
	_apply_button_styles(theme, "SecondaryButton", _box(Color(ACCENT, 0.07), 7, Color(ACCENT, 0.46), 1, 12), _box(Color(ACCENT, 0.13), 7, ACCENT, 1, 12), _box(Color(ACCENT, 0.20), 7, ACCENT, 1, 12))

	theme.set_type_variation("GhostButton", "Button")
	_apply_button_styles(theme, "GhostButton", _box(Color.TRANSPARENT, 7, Color.TRANSPARENT, 0, 10), _box(Color(TEXT, 0.055), 7, Color.TRANSPARENT, 0, 10), _box(Color(TEXT, 0.095), 7, Color.TRANSPARENT, 0, 10))
	theme.set_color("font_color", "GhostButton", TEXT_MUTED)
	theme.set_color("font_hover_color", "GhostButton", TEXT)

	theme.set_type_variation("NavButton", "Button")
	_apply_button_styles(theme, "NavButton", _box(Color.TRANSPARENT, 6, Color.TRANSPARENT, 0, 11), _box(Color(TEXT, 0.055), 6, Color.TRANSPARENT, 0, 11), _box(Color(ACCENT, 0.09), 6, Color(ACCENT, 0.38), 1, 11))
	theme.set_color("font_color", "NavButton", TEXT_MUTED)
	theme.set_color("font_hover_color", "NavButton", TEXT)

	theme.set_type_variation("NavButtonActive", "Button")
	_apply_button_styles(theme, "NavButtonActive", _box(Color(ACCENT, 0.12), 6, Color(ACCENT, 0.46), 1, 11), _box(Color(ACCENT, 0.17), 6, ACCENT, 1, 11), _box(Color(ACCENT, 0.22), 6, ACCENT, 1, 11))
	theme.set_color("font_color", "NavButtonActive", TEXT)
	theme.set_color("font_hover_color", "NavButtonActive", TEXT)

	theme.set_type_variation("TeamCardButton", "Button")
	_apply_button_styles(theme, "TeamCardButton", _box(SURFACE, 9, BORDER_SOFT, 1, 15), _box(SURFACE_RAISED, 9, Color(BLUE, 0.55), 1, 15, true), _box(BLUE_DARK, 9, BLUE, 2, 15))
	theme.set_color("font_color", "TeamCardButton", TEXT)
	theme.set_color("font_pressed_color", "TeamCardButton", TEXT)
	theme.set_color("font_hover_color", "TeamCardButton", TEXT)

	theme.set_type_variation("DangerButton", "Button")
	_apply_button_styles(theme, "DangerButton", _box(Color(DANGER, 0.08), 7, Color(DANGER, 0.48), 1, 12), _box(Color(DANGER, 0.16), 7, DANGER, 1, 12), _box(Color(DANGER, 0.24), 7, DANGER, 1, 12))
	theme.set_color("font_color", "DangerButton", DANGER)
	theme.set_color("font_hover_color", "DangerButton", TEXT)


static func _apply_button_styles(theme: Theme, variation: String, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat) -> void:
	theme.set_stylebox("normal", variation, normal)
	theme.set_stylebox("hover", variation, hover)
	theme.set_stylebox("pressed", variation, pressed)
	theme.set_stylebox("focus", variation, hover)
	theme.set_stylebox("disabled", variation, _box(Color(SURFACE, 0.25), 7, Color(BORDER, 0.28), 1, 12))


static func _add_option_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "OptionButton", _box(SURFACE_SOFT, 7, BORDER, 1, 12))
	theme.set_stylebox("hover", "OptionButton", _box(SURFACE_HOVER, 7, Color(ACCENT, 0.48), 1, 12))
	theme.set_stylebox("pressed", "OptionButton", _box(ACCENT_DARK, 7, ACCENT, 1, 12))
	theme.set_stylebox("focus", "OptionButton", _box(SURFACE_SOFT, 7, ACCENT, 1, 12))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT)
	theme.set_constant("arrow_margin", "OptionButton", 12)


static func _add_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _box(BACKGROUND_SOFT, 7, BORDER, 1, 11))
	theme.set_stylebox("focus", "LineEdit", _box(SURFACE, 7, ACCENT, 1, 11))
	theme.set_stylebox("read_only", "LineEdit", _box(Color(SURFACE, 0.42), 7, BORDER_SOFT, 1, 11))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.28))


static func _add_check_button(theme: Theme) -> void:
	theme.set_color("font_color", "CheckButton", TEXT_MUTED)
	theme.set_color("font_hover_color", "CheckButton", TEXT)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)
	theme.set_color("font_disabled_color", "CheckButton", TEXT_FAINT)


static func _add_popup_menu(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", _box(SURFACE_RAISED, 8, BORDER, 1, 8, true))
	theme.set_stylebox("hover", "PopupMenu", _box(Color(ACCENT, 0.10), 5, Color.TRANSPARENT, 0, 6))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_separator_color", "PopupMenu", TEXT_FAINT)
	theme.set_constant("v_separation", "PopupMenu", 6)


static func _add_progress_bar(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _box(INK, 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 4, Color.TRANSPARENT, 0, 0))
	theme.set_color("font_color", "ProgressBar", Color.TRANSPARENT)


static func _add_scroll_bar(theme: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("scroll", "VScrollBar", empty)
	theme.set_stylebox("grabber", "VScrollBar", _box(Color(BORDER, 0.72), 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(TEXT_MUTED, 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(ACCENT, 4, Color.TRANSPARENT, 0, 0))


static func _add_separators(theme: Theme) -> void:
	var separator := StyleBoxLine.new()
	separator.color = Color(BORDER, 0.65)
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)


static func _box(color: Color, radius: int, border_color: Color, border_width: int, padding: int, with_shadow: bool = false) -> StyleBoxFlat:
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
	if with_shadow:
		style.shadow_color = Color(0, 0, 0, 0.28)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = true
	return style
