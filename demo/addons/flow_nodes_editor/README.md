=== TODO

[ ] Spline sampling interior in non grid pattern
[ ] Add noise to position
[ ] Make vector from float's, maybe autopromote float -> vector3 
[ ] The sample spline is not honoring the uniform interval override value
[ ] Math Node. Should hide/not require some inputs when not needed. Like Abs
[ ] Math Node. Should be easier to add a constant +float/+int/-vector at least
[ ] Math Node. Accept a stream feeding a single size element -> Promote it
[ ] Support for Vector4/Color/PackedVector4Array -> Read SubAttributes / MathNode / SetAttribute / Use in Debug if exists
[ ] Test random colors for each node -> Graph Editor Settings
[ ] Promote input pin to graph input
[ ] use inputs on all settings
[ ] Custom inputs to the pcg
[ ] nodes to filter A/B
[ ] undo/redo
[X] Confirm if we are using PackedStringArray for streams of type Strings
[X] Confirm I can set values of the generated instances
[X] spatial operations
	[X] A minus B
	[X] A intersection B
[X] Remove self intersections
[X] When changing scene, the registered nodes should be removed
[X] Confirm I can use Index as part of the streams
[X] Spline region - Spline path
[X] Node to scan nodes 
[X] Read meta into the attributes
[X] Read properties from list
[X] store sizes
[X] display density/color in debug
[X] input nodes are not restored correctly
[X] support for bools
[X] Move isFinal to getMeta
[X] Spawn PackedScene
[X] store rotations
[x] read-write sub-streams
	[x] vector3 -> .x, .y, .z
	[x] basis   -> yaw, pitch, roll
[x] Choose mesh to spawn
[x] Stream to ref mesh instance
[x] Multic Constant as Arg vs Attribute input
	[x] Conditional UI
[X] Aggregate MultiInstanceMesh per mesh in spawn meshes
[x] dispay substreams
[x] node transform with ranges in local space
[x] save graph into scene node 
[x] dependencies/dirty chains
[X] node add density
[X] update data_view on each refresh
[X] node operate
[X] create custom stream
[x] spline sampling
[x] support for prev
[X] Dynamic title
[X] update while changing the scene
[X] Block auto-update
