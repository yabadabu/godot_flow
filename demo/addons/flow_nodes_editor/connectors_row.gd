@tool
extends HBoxContainer
class_name FlowConnectorRow

var data : Dictionary = {}
signal in_popup
signal out_popup

func getInLabel() -> Label:
	return $LabelIn

func getOutLabel() -> Label:
	return $LabelOut
	
func getNode() -> FlowNodeBase:
	return get_parent() as FlowNodeBase

func _on_label_in_mouse_entered():	
	in_popup.emit()

func _on_label_in_mouse_exited():
	out_popup.emit()

func setData( new_data : Dictionary ):
	data = new_data
	getInLabel().text = data.in_label
	getOutLabel().text = ""

func isParameter() -> bool:
	return data && data.get( "is_parameter", false )
