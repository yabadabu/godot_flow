extends Node
class_name FlowNodeStyle

static func getCategoryColor( category : String ) -> Color:
	var h = hash(category) % 360
	return Color.from_hsv(float(h) / 360.0, 0.3, 0.3)
