extends Node
class_name FlowNodeStyle

static func getCategoryColor( category : String ) -> Color:
	if category == "Math":
		return Color( 0.1, 0.2, 0.3 )
	if category == "Filter":
		return Color( 0.2, 0.1, 0.3 )
	var h = (hash(category)) % 360
	return Color.from_hsv(float(h) / 360.0, 0.2, 0.2)
