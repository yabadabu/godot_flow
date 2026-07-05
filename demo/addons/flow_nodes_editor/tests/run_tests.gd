@tool
extends EditorScript

# Open this script in the editor, then press Ctrl+Shift+X

func _find_test_files(dir_path: String) -> Array:
	var files := []
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				files += _find_test_files(dir_path.path_join(file_name))
			elif file_name.begins_with("test_") and file_name.ends_with(".gd"):
				files.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func _run():
	var total := 0
	var passed := 0
	var failures := {}
	for path in _find_test_files("res://addons/flow_nodes_editor/tests"):
		var script = load(path)
		if not script.can_instantiate():
			print( "Can't instantiate %s" % script)
			continue
		print( "Testing %s" % path)
		for m in script.get_script_method_list():
			if m.name.begins_with("test_"):
				total += 1
				var instance = script.new()
				instance.call(m.name)
				var fails = instance.get_failures()
				if fails.is_empty():
					passed += 1
					print("PASS: %s.%s" % [path.get_file(), m.name])
				else:
					failures["%s.%s" % [path.get_file(), m.name]] = fails
					print("FAIL: %s.%s" % [path.get_file(), m.name])				
	print("\n%d/%d passed" % [passed, total])
	if not failures.is_empty():
		print("\nFailure details:")
		for key in failures:
			for f in failures[key]:
				print("  %s -> %s" % [key, f])
