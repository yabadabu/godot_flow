@tool
class_name GDRTreeGD
extends RefCounted

var centers: PackedVector3Array = PackedVector3Array()
var sizes: PackedVector3Array = PackedVector3Array()

func clear() -> void:
	centers.clear()
	sizes.clear()

func add(in_centers: PackedVector3Array, in_sizes: PackedVector3Array) -> bool:
	if in_centers.size() != in_sizes.size():
		return false
	centers.append_array(in_centers)
	sizes.append_array(in_sizes)
	return true

static func check_aabb_overlap(c1: Vector3, s1: Vector3, c2: Vector3, s2: Vector3) -> bool:
	var min1 := c1 - s1 * 0.5
	var max1 := c1 + s1 * 0.5
	var min2 := c2 - s2 * 0.5
	var max2 := c2 + s2 * 0.5
	return (min1.x < max2.x and max1.x > min2.x) and \
		   (min1.y < max2.y and max1.y > min2.y) and \
		   (min1.z < max2.z and max1.z > min2.z)

func overlaps(others_centers: PackedVector3Array, others_sizes: PackedVector3Array, return_overlapped: bool) -> Dictionary:
	var size_A := centers.size()
	var size_B := others_centers.size()
	
	var bit_buffer := []
	bit_buffer.resize(size_A)
	bit_buffer.fill(false)
	
	if size_A > 0 and size_B > 0:
		for j in range(size_B):
			var cB := others_centers[j]
			var sB := others_sizes[j]
			for i in range(size_A):
				if check_aabb_overlap(centers[i], sizes[i], cB, sB):
					bit_buffer[i] = true
	
	var idxs_overlapped := PackedInt32Array()
	for i in range(size_A):
		if bit_buffer[i] == return_overlapped:
			idxs_overlapped.append(i)
			
	return {
		"result": true,
		"idxs_overlapped": idxs_overlapped
	}

func self_prune(in_centers: PackedVector3Array, in_sizes: PackedVector3Array, return_overlapped: bool) -> Dictionary:
	var i_max := in_centers.size()
	var bit_buffer := []
	bit_buffer.resize(i_max)
	bit_buffer.fill(false)
	
	for i in range(i_max):
		var cI := in_centers[i]
		var sI := in_sizes[i]
		var overlapped := false
		for j in range(centers.size()):
			if check_aabb_overlap(centers[j], sizes[j], cI, sI):
				overlapped = true
				break
		if overlapped:
			bit_buffer[i] = true
		else:
			centers.append(cI)
			sizes.append(sI)
			
	var idxs_overlapped := PackedInt32Array()
	for i in range(i_max):
		if bit_buffer[i] == return_overlapped:
			idxs_overlapped.append(i)
			
	return {
		"result": true,
		"idxs_overlapped": idxs_overlapped
	}
