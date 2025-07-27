@tool
extends HBoxContainer
class_name FlowConnectorRow

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
