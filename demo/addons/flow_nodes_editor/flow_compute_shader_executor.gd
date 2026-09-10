@tool
class_name FlowComputeShaderExecutor
extends RefCounted

const SHADER_SOURCE = preload("res://addons/flow_nodes_editor/flow_compute_shader_source.gd")

const FLOW_DATA_TYPES := {
	"int": FlowData.DataType.Int,
	"float": FlowData.DataType.Float,
	"vec3": FlowData.DataType.Vector,
	"vec4": FlowData.DataType.Color,
}

var _rd: RenderingDevice = null
var _cached_source := ""
var _cached_local_size_x := -1
var _cached_compiled: Dictionary = {}
var _cached_error := ""
var _shader := RID()
var _pipeline := RID()
var _compile_count := 0


static func execute(
	source_code: String,
	input_data: FlowData.Data,
	parameter_values: Dictionary = {},
	local_size_x := SHADER_SOURCE.DEFAULT_LOCAL_SIZE_X,
	profile_enabled := false
) -> Dictionary:
	var executor := FlowComputeShaderExecutor.new()
	var result := executor.execute_cached(
		source_code, input_data, parameter_values, local_size_x, profile_enabled
	)
	executor.dispose()
	return result


func execute_cached(
	source_code: String,
	input_data: FlowData.Data,
	parameter_values: Dictionary = {},
	local_size_x := SHADER_SOURCE.DEFAULT_LOCAL_SIZE_X,
	profile_enabled := false
) -> Dictionary:
	var execution_start := Time.get_ticks_usec() if profile_enabled else 0
	if input_data == null:
		return _error("Compute shader input data is null.")

	var prepared_pipeline := _ensure_pipeline(source_code, local_size_x, profile_enabled)
	if not prepared_pipeline.ok:
		var failed := _error(prepared_pipeline.error, _cached_compiled)
		if profile_enabled:
			failed["profile"] = prepared_pipeline.get("profile", {})
		return failed

	var result := _execute_compiled(
		_rd,
		_cached_compiled,
		input_data,
		parameter_values,
		_shader,
		_pipeline,
		profile_enabled
	)
	result["compiled"] = _cached_compiled
	result["shader_reused"] = prepared_pipeline.reused
	if profile_enabled:
		var profile: Dictionary = prepared_pipeline.get("profile", {})
		profile.merge(result.get("profile", {}), true)
		profile["shader_reused"] = prepared_pipeline.reused
		profile["point_count"] = input_data.size()
		profile["total_us"] = Time.get_ticks_usec() - execution_start
		result["profile"] = profile
	return result


func get_compile_count() -> int:
	return _compile_count


func dispose() -> void:
	_release_pipeline()
	if _rd != null:
		_rd.free()
		_rd = null
	_cached_source = ""
	_cached_local_size_x = -1
	_cached_compiled = {}
	_cached_error = ""


func _ensure_pipeline(
	source_code: String,
	local_size_x: int,
	profile_enabled: bool
) -> Dictionary:
	var profile := {}
	var prepare_start := Time.get_ticks_usec() if profile_enabled else 0
	if _rd == null:
		var device_start := Time.get_ticks_usec() if profile_enabled else 0
		_rd = RenderingServer.create_local_rendering_device()
		if profile_enabled:
			profile["device_create_us"] = Time.get_ticks_usec() - device_start
		if _rd == null:
			return {
				"ok": false,
				"error": "Unable to create a local RenderingDevice.",
				"profile": profile,
			}
	elif profile_enabled:
		profile["device_create_us"] = 0

	var cache_matches := (
		source_code == _cached_source
		and local_size_x == _cached_local_size_x
	)
	if cache_matches:
		if profile_enabled:
			profile["compile_reflect_us"] = 0
			profile["shader_pipeline_create_us"] = 0
			profile["pipeline_prepare_us"] = Time.get_ticks_usec() - prepare_start
		if not _cached_error.is_empty():
			return {"ok": false, "error": _cached_error, "profile": profile}
		return {"ok": true, "error": "", "reused": true, "profile": profile}

	_release_pipeline()
	_cached_source = source_code
	_cached_local_size_x = local_size_x
	_cached_error = ""
	var compile_start := Time.get_ticks_usec() if profile_enabled else 0
	_cached_compiled = SHADER_SOURCE.compile_and_reflect(
		_rd, source_code, local_size_x
	)
	if profile_enabled:
		profile["compile_reflect_us"] = Time.get_ticks_usec() - compile_start
	_compile_count += 1
	if not _cached_compiled.ok:
		_cached_error = _cached_compiled.error
		if profile_enabled:
			profile["shader_pipeline_create_us"] = 0
			profile["pipeline_prepare_us"] = Time.get_ticks_usec() - prepare_start
		return {"ok": false, "error": _cached_error, "profile": profile}

	var pipeline_start := Time.get_ticks_usec() if profile_enabled else 0
	_shader = _rd.shader_create_from_spirv(_cached_compiled.spirv)
	if not _shader.is_valid():
		_cached_error = "Unable to create the compute shader from SPIR-V."
		return {"ok": false, "error": _cached_error, "profile": profile}
	_pipeline = _rd.compute_pipeline_create(_shader)
	if not _pipeline.is_valid():
		_cached_error = "Unable to create the compute pipeline."
		_release_pipeline()
		return {"ok": false, "error": _cached_error, "profile": profile}
	if profile_enabled:
		profile["shader_pipeline_create_us"] = Time.get_ticks_usec() - pipeline_start
		profile["pipeline_prepare_us"] = Time.get_ticks_usec() - prepare_start
	return {"ok": true, "error": "", "reused": false, "profile": profile}


func _release_pipeline() -> void:
	if _rd != null:
		if _pipeline.is_valid():
			_rd.free_rid(_pipeline)
		if _shader.is_valid():
			_rd.free_rid(_shader)
	_pipeline = RID()
	_shader = RID()


static func _execute_compiled(
	rd: RenderingDevice,
	compiled: Dictionary,
	input_data: FlowData.Data,
	parameter_values: Dictionary,
	shader: RID,
	pipeline: RID,
	profile_enabled: bool
) -> Dictionary:
	var profile := {}
	var prepare_start := Time.get_ticks_usec() if profile_enabled else 0
	var prepared := _prepare_buffers(compiled, input_data, profile_enabled)
	if profile_enabled:
		profile["data_prepare_us"] = Time.get_ticks_usec() - prepare_start
		profile["data_duplicate_us"] = prepared.get("duplicate_us", 0)
	if not prepared.ok:
		return prepared

	var parameter_start := Time.get_ticks_usec() if profile_enabled else 0
	var parameter_bytes := _pack_parameters(
		compiled, input_data.size(), parameter_values
	)
	if profile_enabled:
		profile["parameter_pack_us"] = Time.get_ticks_usec() - parameter_start
	if not parameter_bytes.ok:
		return parameter_bytes

	# Empty datasets still need their declared outputs, but require no GPU work.
	if input_data.size() == 0:
		var empty_result := _write_output_data(
			prepared.output_data, prepared.buffers, [], profile_enabled
		)
		if profile_enabled:
			profile.merge(empty_result.get("profile", {}), true)
			profile["buffers"] = _buffer_profiles(prepared.buffers)
			empty_result["profile"] = profile
		return empty_result

	var owned_rids: Array[RID] = []
	var uniform_rids: Array[RID] = []
	var uniforms: Array[RDUniform] = []
	var parameter_buffer_start := Time.get_ticks_usec() if profile_enabled else 0
	var parameter_buffer: RID = rd.uniform_buffer_create(
		parameter_bytes.bytes.size(), parameter_bytes.bytes
	)
	if profile_enabled:
		profile["parameter_buffer_create_us"] = (
			Time.get_ticks_usec() - parameter_buffer_start
		)
	if not parameter_buffer.is_valid():
		_free_rids(rd, owned_rids)
		return _error("Unable to create the FlowParameters uniform buffer.")
	owned_rids.append(parameter_buffer)
	uniform_rids.append(parameter_buffer)
	uniforms.append(_make_uniform(
		RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, 0, parameter_buffer
	))

	var storage_create_start := Time.get_ticks_usec() if profile_enabled else 0
	for buffer in prepared.buffers:
		var buffer_create_start := Time.get_ticks_usec() if profile_enabled else 0
		var storage_buffer: RID = rd.storage_buffer_create(buffer.bytes.size(), buffer.bytes)
		if profile_enabled:
			buffer.profile["gpu_buffer_create_us"] = (
				Time.get_ticks_usec() - buffer_create_start
			)
		if not storage_buffer.is_valid():
			_free_rids(rd, owned_rids)
			return _error("Unable to create GPU buffer '%s'." % buffer.declaration.name)
		owned_rids.append(storage_buffer)
		uniform_rids.append(storage_buffer)
		uniforms.append(_make_uniform(
			RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
			buffer.declaration.binding,
			storage_buffer
		))
	if profile_enabled:
		profile["storage_buffers_create_us"] = Time.get_ticks_usec() - storage_create_start

	var uniform_set_start := Time.get_ticks_usec() if profile_enabled else 0
	var uniform_set: RID = rd.uniform_set_create(uniforms, shader, 0)
	if profile_enabled:
		profile["uniform_set_create_us"] = Time.get_ticks_usec() - uniform_set_start
	if not uniform_set.is_valid():
		_free_rids(rd, owned_rids)
		return _error("Unable to create the compute shader uniform set.")
	owned_rids.append(uniform_set)

	var timestamp_start_index := -1
	if profile_enabled:
		timestamp_start_index = rd.get_captured_timestamps_count()
		rd.capture_timestamp("Flow compute begin")
	var command_start := Time.get_ticks_usec() if profile_enabled else 0
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var group_count := ceili(float(input_data.size()) / float(compiled.local_size_x))
	rd.compute_list_dispatch(compute_list, group_count, 1, 1)
	rd.compute_list_end()
	if profile_enabled:
		profile["command_record_us"] = Time.get_ticks_usec() - command_start
		rd.capture_timestamp("Flow compute end")
	var submit_start := Time.get_ticks_usec() if profile_enabled else 0
	rd.submit()
	if profile_enabled:
		profile["submit_us"] = Time.get_ticks_usec() - submit_start
	var sync_start := Time.get_ticks_usec() if profile_enabled else 0
	rd.sync()
	if profile_enabled:
		profile["sync_us"] = Time.get_ticks_usec() - sync_start
		profile["gpu_dispatch_us"] = _read_gpu_dispatch_time_us(
			rd, timestamp_start_index
		)

	var downloaded: Array[PackedByteArray] = []
	var download_start := Time.get_ticks_usec() if profile_enabled else 0
	for buffer_index in prepared.buffers.size():
		var buffer_download_start := Time.get_ticks_usec() if profile_enabled else 0
		var declaration: Dictionary = prepared.buffers[buffer_index].declaration
		if declaration.kind == "ro":
			downloaded.append(PackedByteArray())
		else:
			downloaded.append(rd.buffer_get_data(uniform_rids[buffer_index + 1]))
		if profile_enabled:
			prepared.buffers[buffer_index].profile["download_us"] = (
				Time.get_ticks_usec() - buffer_download_start
				if declaration.kind != "ro" else 0
			)
	if profile_enabled:
		profile["download_us"] = Time.get_ticks_usec() - download_start

	var result := _write_output_data(
		prepared.output_data, prepared.buffers, downloaded, profile_enabled
	)
	if profile_enabled:
		profile.merge(result.get("profile", {}), true)
	var cleanup_start := Time.get_ticks_usec() if profile_enabled else 0
	_free_rids(rd, owned_rids)
	if profile_enabled:
		profile["rid_cleanup_us"] = Time.get_ticks_usec() - cleanup_start
		profile["buffers"] = _buffer_profiles(prepared.buffers)
		result["profile"] = profile
	return result



static func _prepare_buffers(
	compiled: Dictionary,
	input_data: FlowData.Data,
	profile_enabled: bool
) -> Dictionary:
	var duplicate_start := Time.get_ticks_usec() if profile_enabled else 0
	var output_data := input_data.duplicate()
	var duplicate_us := (
		Time.get_ticks_usec() - duplicate_start if profile_enabled else 0
	)
	var prepared: Array[Dictionary] = []
	for declaration in compiled.buffers:
		if not FLOW_DATA_TYPES.has(declaration.type):
			return _error("Buffer type '%s' cannot be represented by FlowData." % declaration.type)

		var stream: Variant = input_data.findStream(declaration.name)
		if declaration.kind == "out":
			if stream != null:
				return _error("Output attribute '%s' already exists." % declaration.name)
		else:
			if stream == null:
				return _error("Input attribute '%s' was not found." % declaration.name)
			var expected_data_type: int = FLOW_DATA_TYPES[declaration.type]
			if stream.data_type != expected_data_type:
				return _error("Attribute '%s' should be %s, but is %s." % [
					declaration.name,
					declaration.type,
					FlowData.DataType.keys()[stream.data_type],
				])
			if stream.container.size() != input_data.size():
				return _error("Attribute '%s' has %d values; expected %d." % [
					declaration.name, stream.container.size(), input_data.size()
				])

		var reflected: Dictionary = _find_binding(
			compiled.reflection.storage_buffers, declaration.binding
		)
		var buffer_bytes := PackedByteArray()
		var pack_start := Time.get_ticks_usec() if profile_enabled else 0
		if declaration.kind == "out":
			buffer_bytes.resize(input_data.size() * reflected.element_stride)
		elif declaration.type == "vec3":
			buffer_bytes = GDStreamUtils.pack_vec3_f32(
				stream.container, reflected.element_stride
			)
		else:
			buffer_bytes.resize(input_data.size() * reflected.element_stride)
			_pack_stream(buffer_bytes, stream.container, declaration.type, reflected.element_stride)
		var buffer_profile := {
			"name": declaration.name,
			"kind": declaration.kind,
			"type": declaration.type,
			"bytes": buffer_bytes.size(),
			"stride": reflected.element_stride,
			"cpu_pack_us": (
				Time.get_ticks_usec() - pack_start
				if profile_enabled and declaration.kind != "out" else 0
			),
		}
		prepared.append({
			"declaration": declaration,
			"bytes": buffer_bytes,
			"stride": reflected.element_stride,
			"profile": buffer_profile,
		})

	return {
		"ok": true,
		"error": "",
		"output_data": output_data,
		"buffers": prepared,
		"duplicate_us": duplicate_us,
	}


static func _pack_parameters(
	compiled: Dictionary,
	flow_size: int,
	parameter_values: Dictionary
) -> Dictionary:
	var reflected_buffer := _find_binding(compiled.reflection.constant_buffers, 0)
	var byte_size: int = maxi(reflected_buffer.size, reflected_buffer.padded_size)
	var bytes := PackedByteArray()
	bytes.resize(byte_size)

	var size_member := _find_named(reflected_buffer.members, "FlowSize")
	bytes.encode_u32(size_member.offset, flow_size)
	for parameter in compiled.parameters:
		var member := _find_named(reflected_buffer.members, parameter.name)
		var value = parameter_values.get(parameter.name, _default_parameter(parameter.type))
		var write_error := _encode_parameter(bytes, member.offset, parameter.type, value)
		if not write_error.is_empty():
			return _error("Parameter '%s': %s" % [parameter.name, write_error])
	return {"ok": true, "error": "", "bytes": bytes}


static func _pack_stream(
	bytes: PackedByteArray,
	container,
	data_type: String,
	stride: int
) -> void:
	for index in container.size():
		var offset: int = index * stride
		match data_type:
			"int":
				bytes.encode_s32(offset, container[index])
			"float":
				bytes.encode_float(offset, container[index])
			"vec3":
				var value: Vector3 = container[index]
				bytes.encode_float(offset, value.x)
				bytes.encode_float(offset + 4, value.y)
				bytes.encode_float(offset + 8, value.z)
			"vec4":
				var value: Color = container[index]
				bytes.encode_float(offset, value.r)
				bytes.encode_float(offset + 4, value.g)
				bytes.encode_float(offset + 8, value.b)
				bytes.encode_float(offset + 12, value.a)


static func _unpack_stream(
	bytes: PackedByteArray,
	data_type: String,
	stride: int,
	count: int
):
	match data_type:
		"int":
			var values := PackedInt32Array()
			values.resize(count)
			for index in count:
				values[index] = bytes.decode_s32(index * stride)
			return values
		"float":
			var values := PackedFloat32Array()
			values.resize(count)
			for index in count:
				values[index] = bytes.decode_float(index * stride)
			return values
		"vec3":
			return GDStreamUtils.unpack_vec3_f32(bytes, count, stride)
		"vec4":
			var values := PackedColorArray()
			values.resize(count)
			for index in count:
				var offset := index * stride
				values[index] = Color(
					bytes.decode_float(offset),
					bytes.decode_float(offset + 4),
					bytes.decode_float(offset + 8),
					bytes.decode_float(offset + 12)
				)
			return values
	return null


static func _write_output_data(
	output_data: FlowData.Data,
	prepared_buffers: Array,
	downloaded: Array,
	profile_enabled: bool
) -> Dictionary:
	var unpack_total_start := Time.get_ticks_usec() if profile_enabled else 0
	for index in prepared_buffers.size():
		var buffer: Dictionary = prepared_buffers[index]
		var declaration: Dictionary = buffer.declaration
		if declaration.kind == "ro":
			if profile_enabled:
				buffer.profile["cpu_unpack_us"] = 0
			continue
		var unpack_start := Time.get_ticks_usec() if profile_enabled else 0
		var bytes: PackedByteArray = downloaded[index] if not downloaded.is_empty() else buffer.bytes
		var container = _unpack_stream(
			bytes, declaration.type, buffer.stride, output_data.size()
		)
		if profile_enabled:
			buffer.profile["cpu_unpack_us"] = Time.get_ticks_usec() - unpack_start
		var register_error = output_data.registerStream(
			declaration.name, container, FLOW_DATA_TYPES[declaration.type]
		)
		if register_error != null:
			return _error(str(register_error))
	return {
		"ok": true,
		"error": "",
		"data": output_data,
		"profile": {
			"output_unpack_us": (
				Time.get_ticks_usec() - unpack_total_start if profile_enabled else 0
			),
		},
	}


static func _encode_parameter(
	bytes: PackedByteArray,
	offset: int,
	data_type: String,
	value
) -> String:
	match data_type:
		"bool":
			if not value is bool:
				return "expected bool."
			bytes.encode_u32(offset, 1 if value else 0)
		"int":
			if not value is int:
				return "expected int."
			bytes.encode_s32(offset, value)
		"uint":
			if not value is int or value < 0:
				return "expected a non-negative int."
			bytes.encode_u32(offset, value)
		"float":
			if not (value is float or value is int):
				return "expected float."
			bytes.encode_float(offset, float(value))
		"vec2":
			if not value is Vector2:
				return "expected Vector2."
			_encode_float_components(bytes, offset, [value.x, value.y])
		"vec3":
			if not value is Vector3:
				return "expected Vector3."
			_encode_float_components(bytes, offset, [value.x, value.y, value.z])
		"vec4":
			if value is Vector4:
				_encode_float_components(bytes, offset, [value.x, value.y, value.z, value.w])
			elif value is Color:
				_encode_float_components(bytes, offset, [value.r, value.g, value.b, value.a])
			else:
				return "expected Vector4 or Color."
		"ivec2":
			if not value is Vector2i:
				return "expected Vector2i."
			_encode_int_components(bytes, offset, [value.x, value.y])
		"ivec3":
			if not value is Vector3i:
				return "expected Vector3i."
			_encode_int_components(bytes, offset, [value.x, value.y, value.z])
		"ivec4":
			if not value is Vector4i:
				return "expected Vector4i."
			_encode_int_components(bytes, offset, [value.x, value.y, value.z, value.w])
		"uvec2":
			if not value is Vector2i:
				return "expected Vector2i with non-negative components."
			return _encode_uint_components(bytes, offset, [value.x, value.y])
		"uvec3":
			if not value is Vector3i:
				return "expected Vector3i with non-negative components."
			return _encode_uint_components(bytes, offset, [value.x, value.y, value.z])
		"uvec4":
			if not value is Vector4i:
				return "expected Vector4i with non-negative components."
			return _encode_uint_components(bytes, offset, [value.x, value.y, value.z, value.w])
		_:
			return "unsupported type '%s'." % data_type
	return ""


static func _encode_float_components(bytes: PackedByteArray, offset: int, values: Array) -> void:
	for index in values.size():
		bytes.encode_float(offset + index * 4, values[index])


static func _encode_int_components(bytes: PackedByteArray, offset: int, values: Array) -> void:
	for index in values.size():
		bytes.encode_s32(offset + index * 4, values[index])


static func _encode_uint_components(bytes: PackedByteArray, offset: int, values: Array) -> String:
	for index in values.size():
		if values[index] < 0:
			return "expected non-negative components."
		bytes.encode_u32(offset + index * 4, values[index])
	return ""


static func _default_parameter(data_type: String):
	match data_type:
		"bool": return false
		"int", "uint", "float": return 0
		"vec2": return Vector2.ZERO
		"vec3": return Vector3.ZERO
		"vec4": return Vector4.ZERO
		"ivec2": return Vector2i.ZERO
		"ivec3": return Vector3i.ZERO
		"ivec4": return Vector4i.ZERO
		"uvec2": return Vector2i.ZERO
		"uvec3": return Vector3i.ZERO
		"uvec4": return Vector4i.ZERO
	return null


static func _make_uniform(type: int, binding: int, id: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	uniform.add_id(id)
	return uniform


static func _free_rids(rd: RenderingDevice, rids: Array[RID]) -> void:
	for index in range(rids.size() - 1, -1, -1):
		if rids[index].is_valid():
			rd.free_rid(rids[index])


static func _buffer_profiles(prepared_buffers: Array) -> Array:
	var profiles := []
	for buffer in prepared_buffers:
		profiles.append(buffer.profile)
	return profiles


static func _read_gpu_dispatch_time_us(rd: RenderingDevice, start_index: int) -> float:
	if start_index < 0:
		return -1.0
	var count := rd.get_captured_timestamps_count()
	if count < start_index + 2:
		return -1.0
	if (
		rd.get_captured_timestamp_name(start_index) != "Flow compute begin"
		or rd.get_captured_timestamp_name(start_index + 1) != "Flow compute end"
	):
		return -1.0
	# RenderingDevice's Vulkan backend returns timestamp values in nanoseconds.
	# Convert the delta to the microseconds used by the rest of this profile.
	var elapsed_ns := maxi(
		0,
		rd.get_captured_timestamp_gpu_time(start_index + 1)
		- rd.get_captured_timestamp_gpu_time(start_index)
	)
	return float(elapsed_ns) / 1000.0


static func format_profile(profile: Dictionary) -> String:
	if profile.is_empty():
		return "Compute shader profiling was not enabled."
	var lines := PackedStringArray([
		"Compute Shader: %d points, %d us total%s" % [
			profile.get("point_count", 0),
			profile.get("total_us", 0),
			" (cached pipeline)" if profile.get("shader_reused", false) else "",
		],
		"  pipeline: %d us [device %d, compile+reflect %d, shader+pipeline %d]" % [
			profile.get("pipeline_prepare_us", 0),
			profile.get("device_create_us", 0),
			profile.get("compile_reflect_us", 0),
			profile.get("shader_pipeline_create_us", 0),
		],
		"  CPU pack: %d us [data %d, params %d, duplicate %d]" % [
			profile.get("data_prepare_us", 0) + profile.get("parameter_pack_us", 0),
			profile.get("data_prepare_us", 0),
			profile.get("parameter_pack_us", 0),
			profile.get("data_duplicate_us", 0),
		],
		"  GPU buffers: %d us [params %d, storage %d, uniform set %d]" % [
			profile.get("parameter_buffer_create_us", 0)
				+ profile.get("storage_buffers_create_us", 0)
				+ profile.get("uniform_set_create_us", 0),
			profile.get("parameter_buffer_create_us", 0),
			profile.get("storage_buffers_create_us", 0),
			profile.get("uniform_set_create_us", 0),
		],
		"  dispatch: %d us CPU [record %d, submit %d], %.3f us GPU" % [
			profile.get("command_record_us", 0) + profile.get("submit_us", 0),
			profile.get("command_record_us", 0),
			profile.get("submit_us", 0),
			profile.get("gpu_dispatch_us", -1.0),
		],
		"  wait/sync: %d us" % profile.get("sync_us", 0),
		"  readback: %d us, CPU unpack: %d us, RID cleanup: %d us" % [
			profile.get("download_us", 0),
			profile.get("output_unpack_us", 0),
			profile.get("rid_cleanup_us", 0),
		],
	])
	for buffer in profile.get("buffers", []):
		lines.append(
			"    %s %s %s: %d bytes [pack %d, create/upload %d, download %d, unpack %d] us" % [
				buffer.kind,
				buffer.type,
				buffer.name,
				buffer.bytes,
				buffer.get("cpu_pack_us", 0),
				buffer.get("gpu_buffer_create_us", 0),
				buffer.get("download_us", 0),
				buffer.get("cpu_unpack_us", 0),
			]
		)
	return "\n".join(lines)


static func _find_binding(items: Array, binding: int) -> Dictionary:
	for item in items:
		if item.set == 0 and item.binding == binding:
			return item
	return {}


static func _find_named(items: Array, wanted_name: String) -> Dictionary:
	for item in items:
		if item.name == wanted_name:
			return item
	return {}


static func _error(message: String, compiled: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"data": null,
		"compiled": compiled,
	}
