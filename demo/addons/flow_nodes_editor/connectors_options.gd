@tool
extends HBoxContainer
class_name FlowConnectorOptions

# The small widget added to the nodes with options to show/hide the optional inputs

signal expand_toggled( is_on : bool )

var show_disconnected_inputs : bool

func _ready():
	setShowDisconnectedInputs( show_disconnected_inputs )

func setShowDisconnectedInputs( how : bool ):
	show_disconnected_inputs = how
	$ToggleButton.set_pressed_no_signal(  show_disconnected_inputs )
	
func _on_toggle_button_toggled(toggled_on):
	print( "toggled2: %s" % toggled_on)
	expand_toggled.emit( toggled_on )
