# UE PCG Parity Plan — Conventions & Work Orders

Goal: Unreal PCG users follow UE tutorials inside this addon with minimal translation.
This doc is the single source of truth for conventions used across the parity edits.

## Global conventions (ALL agents follow these)

### 1. Canonical attribute constants (defined in flow_data.gd)
```gdscript
const AttrPosition = "position"   # existing
const AttrRotation = "rotation"   # existing (Euler DEGREES, always)
const AttrSize     = "size"       # existing
const AttrDensity  = "density"    # NEW — Float, 0..1, soft existence probability (UE $Density)
const AttrSeed     = "seed"       # NEW — Int, per-point deterministic seed (UE $Seed)
const AttrNormal   = "normal"     # NEW — Vector, surface normal where known (UE $Position normal source)
```
- Rotation streams are **Euler degrees** everywhere. Nodes writing radians are bugs.
- Use the constants, never the bare string literals, in node code.

### 2. Density semantics (UE parity)
- Samplers (surface_sampler, sample_points, sample_mesh, volume_sampler, grid,
  grid_fill_bounds, sample_spline, texture_sampler) register an AttrDensity stream
  filled with 1.0 on their outputs (after their existing streams).
- Density is 0..1; nodes that write it clamp to 0..1 unless the node explicitly
  documents otherwise.
- Density-consuming nodes resolve a missing density stream as constant 1.0.

### 3. Per-point Seed semantics (UE parity)
- Samplers also register an AttrSeed Int stream:
  `seed_i = FlowData.point_seed(position_i, node_seed)` — new static helper in
  flow_data.gd: hash of position quantized at *1000 combined with the node seed
  (same quantization mutate_seed already uses).
- Stochastic nodes (transform/transform_points, match_and_set, attribute_random,
  select_points, attribute_noise) prefer the point's AttrSeed when the stream is
  present: per-point RNG = seeded with `point_seed ^ node_seed`. When absent,
  keep the existing node-level RNG behavior (back-compat).

### 4. Input guards (no more null-deref crashes)
New helpers in node.gd (FlowNodeBase):
```gdscript
# Returns the FlowData.Data on the port, or null after handling the error path.
# Editor preview (ctx.owner == null and Engine.is_editor_hint()): emits empty
# Data on output 0 and returns null silently. Otherwise: setError + null.
func require_input(port: int, ctx, error_label := "Input") -> FlowData.Data
```
Every node whose execute() dereferences `get_input(n)` unguarded adopts it.
Note get_input may return `[]` for an out-of-range port — the helper handles both.

### 5. Broadcast reads
`FlowData.bcast_idx(container_size: int, i: int) -> int` — returns `i` when
`container_size > 1` else 0, and pushes a per-eval warning (not per point) when
`1 < container_size <= i` (mismatched stream length) instead of silently aliasing.
Adopt at sites flagged in the audit; do not rewrite every node.

### 6. Settings hygiene
- execute() must NOT mutate `settings` (no `settings.operation = X`, no
  `settings.uniform_interval = ...` writebacks). Alias nodes pass their forced
  mode via an instance variable or a parameter to the shared implementation.
- `NodeSettings._init()` keeps `random_seed = randi()` REPLACED by stable
  default `12345` — UE graphs are deterministic by default; per-point seeds
  decorrelate nodes that share the default.
- No `print()` in execute paths (remove leftover debug prints; use trace flag).

### 7. UE aliases in node metadata
Each node's `meta_node` gains `"aliases": [...]` with the exact UE PCG node
name(s) plus high-value synonyms. The search popup already scores aliases.
Canonical map (tutorial-frequency top nodes — use EXACTLY these strings):

| template | aliases |
|---|---|
| spawn_meshes | Static Mesh Spawner |
| surface_sampler | Surface Sampler |
| transform / transform_points | Transform Points |
| scan_meshes | Get Landscape Data, Get Primitive Data |
| density_filter (NEW) | Density Filter |
| scan_splines | Get Spline Data |
| sample_spline | Spline Sampler |
| attribute_noise (NEW) | Attribute Noise, Density Noise |
| normal_to_density (NEW) | Normal To Density |
| difference | Difference |
| substract | (deprecated — alias Difference; title fix "Subtract (Legacy)") |
| self_pruning | Self Pruning |
| bounds_modifier | Bounds Modifier |
| scan_nodes / points_from_scene | Get Actor Data |
| projection (NEW) | Projection |
| ray_cast | World Ray Hit Query, Raycast |
| point_filter_range | Point Filter |
| attribute_filter_range | Attribute Filter |
| copy / copy_points | Copy Points |
| merge / merge_points | Merge, Merge Points |
| filter_data_by_tag | Filter Data By Tag |
| spawn_scenes | Spawn Actor, Scene Spawner |
| spawn_nodes | Spawn Actor (Nodes) |
| add_attribute | Add Attribute, Create Attribute |
| match_and_set | Match And Set Attributes |
| subgraph | Subgraph |
| loop | Loop, For Each |
| get_loop_index | Get Loop Index |
| duplicate_point | Duplicate Point |
| grid | Create Points Grid, Create Points |
| partition | Attribute Partition |
| density_remap | Density Remap |
| curve_remap_density | Curve Remap Density |
| texture_sampler | Get Texture Data, Texture Sampler |
| math_op | Attribute Maths Op |
| expression | Attribute Expression |
| mutate_seed | Mutate Seed |
| select_points | Select Points |
| distance | Distance |
| distance_to_density | Distance To Density |
| point_neighborhood | Point Neighborhood |
| create_spline | Create Spline |
| branch | Branch |
| select / select_multi | Select, Select (Multi) |
| switch | Switch |
| sort | Sort Points, Sort Attributes |
| get_points_count | Get Points Count |
| print_string | Print String |
| sanity_check | Sanity Check Point Data |
| reroute | Reroute (also retitle node from "•" to "Reroute") |
| volume_sampler | Volume Sampler |
| sample_mesh / mesh_sampler | Mesh Sampler |
| physics_overlap_query | World Volumetric Query |
| attribute_rename | Attribute Rename |
| remove_attribute | Delete Attributes |
| point_to_attribute_set | Point To Attribute Set |
| attribute_set_to_point | Attribute Set To Point |
| load_data_table | Load Data Table |
| data_table_row_to_attribute_set | Data Table Row To Attribute Set |
| bounds: make_bounds | Get Bounds |
| combine_points | Combine Points |
| build_rotation_from_up | Build Rotation From Up Vector |
| snap_to_grid | Snap To Grid |
| relax | Relax Points |
| noise | Spatial Noise |
| split_splines | Subdivide Spline (partial), Split Splines |
| apply_on_actor | Apply On Actor |
| point_from_player_pawn | Point From Player Pawn (keep existing aliases) |
| filter_data_by_type | Filter Data By Type |
| filter_data_by_attribute | Filter Data By Attribute |
| add_tags / delete_tags / replace_tags | Add Tags / Delete Tags / Replace Tags |
| input / output | Input / Output |
| boolean | Boolean Op |
| compose_vector / decompose_vector | Make Vector Attribute / Break Vector Attribute |
| attribute_random | Attribute Random (UE: Attribute Noise covers; keep) |
| debug | Debug |
For nodes not in this table, use the `ue_equivalent` field from
`_survey_inventory.json` when sensible; skip aliases that would collide.

### 8. New nodes (Phase B5) — exact specs
- **density_filter.gd** — In → (In Filter, Outside Filter) [UE pin names].
  Settings: lower_bound=0.5, upper_bound=1.0, invert_filter=false.
  Missing density stream = all points density 1.0. Reuses attribute_filter_range
  implementation hardwired to AttrDensity (composition, not copy-paste).
- **attribute_noise.gd** — In → Out. Settings: target_attribute="density"
  (attribute selector), mode enum Set/Minimum/Maximum/Add/Multiply, noise_min=0.0,
  noise_max=1.0, invert_source=false, clamp_result=true (clamps 0..1 when
  targeting density). Per-point seeded (convention #3). Creates the attribute
  if missing (density initialized 1.0 first when targeted).
- **normal_to_density.gd** — In → Out. Settings: normal_to_compare=Vector3.UP,
  offset=0.0, strength=1.0, density_mode enum Set/Minimum/Maximum/Add/Multiply.
  Reads AttrNormal stream; if absent, derives normal from rotation stream
  (up vector). density = clamp(dot(normal.normalized, compare.normalized)
  + offset, 0, 1) ^ strength, combined per density_mode.
- **projection.gd** — port from
  C:/Users/mattk/Documents/tactics/addons/flow_nodes_editor/nodes/project_points.gd
  (+ its settings file). Rename template to `projection`, title "Projection".
  Projects points onto physics geometry along a direction; options to inherit
  rotation from surface normal (writes AttrNormal too).
All four: register in root node_templates.csv, category metadata per #9.

### 9. Categories
`meta_node` gains optional `"category": "Sampler|Spatial|Filter|Density|Metadata|Spawner|ControlFlow|Input|Debug|Utility"`.
search_add_node_popup falls back to its cat_map, then "Utility".
New nodes set it; B agents add it opportunistically while editing a file anyway.

## File ownership (no two agents edit the same file)
- A1: flow_data.gd, node.gd, node_settings.gd
- A2: flow_nodes_io.gd, flow_node.gd, nodes/subgraph.gd, nodes/loop.gd
- A3: flow_editor.gd
- A4: search_add_node_popup.gd, data_inspector.gd, visualization/table_view.gd
- B1–B4: the four survey chunks of nodes/*.gd + *_settings.gd, MINUS files owned
  by A2 (subgraph, loop) and B5 (samplers, new nodes)
- B5: surface_sampler, sample_points, sample_mesh, mesh_sampler, volume_sampler,
  grid, grid_fill_bounds, sample_spline, texture_sampler (+settings), the four
  NEW node files (+settings), node_templates.csv
- C1: README.md, docs/COMING_FROM_UNREAL_PCG.md, docs/PARITY_ROADMAP.md
- C2 (after B5): demos/demo_ue_forest.tscn, graphs/graph_ue_forest.tres

## Out of scope (PARITY_ROADMAP.md documents these honestly)
Hierarchical generation (Grid Size), async/proximity runtime generation, GPU
nodes, per-point BoundsMin/BoundsMax + Steepness, quaternion rotation model,
spatial-data type lattice (surface/volume algebra), shape grammar nodes,
landscape paint-layer sampling, Subdivide Segment, attribute domains (@Data).
