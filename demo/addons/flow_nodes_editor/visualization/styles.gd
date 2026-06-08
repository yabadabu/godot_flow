extends Node
class_name FlowNodeStyle

static func getCategoryColor( category : String ) -> Color:
	if category == "Math":
		return Color( 0.21, 0.1, 0.3 )
	if category == "Filter":
		return Color( 0.4, 0.1, 0.3 )
	if category == "Metadata":
		return Color( 0.1, 0.3, 0.4 )
	var h = (hash(category) * 27) % 360
	return Color.from_hsv(float(h) / 360.0, 0.5, 0.3)
