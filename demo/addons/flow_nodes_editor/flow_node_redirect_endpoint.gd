@tool
class_name FlowNodeRedirectEndpoint
extends FlowNodeBase

@export_storage var redirect_id: StringName

@export var redirect_name: String = "Redirect":
	set(value):
		if redirect_name == value:
			return
		redirect_name = value
		var definition := getRedirectDefinition()
		if definition and definition.name != value:
			definition.name = value
			FlowGraphRedirectors.refreshEndpoints(flow_graph, redirect_id)

var _redirect_definition: FlowGraphRedirect

func bindRedirectDefinition(graph: FlowGraphResource) -> void:
	flow_graph = graph
	var definition := FlowGraphRedirectors.ensureDefinition(
		graph,
		redirect_id,
		redirect_name
	)
	_setRedirectDefinition(definition)

func getRedirectDefinition() -> FlowGraphRedirect:
	if (
		not _redirect_definition
		and flow_graph
		and not redirect_id.is_empty()
	):
		_setRedirectDefinition(
			FlowGraphRedirectors.findDefinition(flow_graph, redirect_id)
		)
	return _redirect_definition

func refreshRedirectDefinition() -> void:
	var definition := getRedirectDefinition()
	if definition:
		redirect_name = definition.name
	notify_property_list_changed()
	connections_changed.emit()
	emit_changed()

func getTitle() -> String:
	var definition := getRedirectDefinition()
	return definition.name if definition else redirect_name

func shouldReevaluateOnPropChanged(prop_name: StringName) -> bool:
	if prop_name == &"redirect_name":
		return false
	return super.shouldReevaluateOnPropChanged(prop_name)

func execute(ctx: FlowData.EvaluationContext) -> void:
	setOutput(ctx, 0, getOptionalInput(ctx, 0))

func _setRedirectDefinition(definition: FlowGraphRedirect) -> void:
	if (
		_redirect_definition
		and _redirect_definition.changed.is_connected(_onRedirectDefinitionChanged)
	):
		_redirect_definition.changed.disconnect(_onRedirectDefinitionChanged)
	_redirect_definition = definition
	if not _redirect_definition:
		return
	redirect_id = _redirect_definition.ensureId()
	redirect_name = _redirect_definition.name
	if not _redirect_definition.changed.is_connected(_onRedirectDefinitionChanged):
		_redirect_definition.changed.connect(_onRedirectDefinitionChanged)

func _onRedirectDefinitionChanged() -> void:
	if not _redirect_definition:
		return
	redirect_name = _redirect_definition.name
	notify_property_list_changed()
	connections_changed.emit()
	emit_changed()
