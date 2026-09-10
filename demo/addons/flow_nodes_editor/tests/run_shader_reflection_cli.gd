extends SceneTree

func _initialize() -> void:
	var test_groups := [
		{
			"path": "res://addons/flow_nodes_editor/tests/test_shader_reflection.gd",
			"names": [
				"test_flow_pragmas_generate_typed_contract",
				"test_flow_pragmas_reject_ambiguous_contracts",
				"test_generated_glsl_compiles_and_matches_reflection",
				"test_precompiled_spirv_reflection",
			],
		},
		{
			"path": "res://addons/flow_nodes_editor/tests/test_compute_shader_executor.gd",
			"names": [
				"test_compute_shader_upload_dispatch_download_is_copy_on_write",
				"test_compute_shader_rejects_wrong_input_attribute_type",
				"test_parameter_changes_reuse_compiled_shader_and_pipeline",
				"test_native_vec3_gpu_buffer_conversion_respects_stride",
			],
		},
		{
			"path": "res://addons/flow_nodes_editor/tests/test_compute_shader_node.gd",
			"names": [
				"test_compute_shader_node_exposes_and_preserves_typed_parameters",
				"test_compute_shader_node_delegates_execution",
				"test_compute_shader_node_serializes_dynamic_parameter_values",
			],
		},
	]
	var failed := false
	for group in test_groups:
		var test_script = load(group.path)
		if test_script == null or not test_script.can_instantiate():
			printerr("Unable to load %s" % group.path)
			failed = true
			continue
		for test_name in group.names:
			var instance = test_script.new()
			instance.call(test_name)
			var failures: Array[String] = instance.get_failures()
			if failures.is_empty():
				print("PASS: %s" % test_name)
			else:
				failed = true
				print("FAIL: %s" % test_name)
				for failure in failures:
					print("  %s" % failure)

	quit(1 if failed else 0)
