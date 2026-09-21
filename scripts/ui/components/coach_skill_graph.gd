class_name CoachSkillGraph
extends GridContainer

var skill_nodes: Dictionary = {}
var definitions: Array = []
var coach: CoachProgressData


func _ready() -> void:
	sort_children.connect(queue_redraw)


func _draw() -> void:
	# Compact screens use explicit prerequisite labels instead of crossing
	# connectors through stacked cards.
	if columns < 2:
		return
	for definition in definitions:
		var target: Control = skill_nodes.get(definition["id"])
		if target == null:
			continue
		for required in definition.get("requires", []):
			var source: Control = skill_nodes.get(required)
			if source == null:
				continue
			var start := source.position + Vector2(source.size.x * 0.5, source.size.y)
			var finish := target.position + Vector2(target.size.x * 0.5, 0)
			var color := GridironTheme.ACCENT if coach.rank_of(str(required)) > 0 else GridironTheme.BORDER
			draw_line(start, finish, color, 2.0, true)
			draw_circle(finish - Vector2(0, 5), 3.0, color)
