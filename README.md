# Description

This is a Godot 4.4 plugin editor to have a similar tool to the Procedural Content Generator (PCG) from Unreal 5.X into Godot. I call the tool Flow Graph

# Install

Copy the ```demo/addons/flow_nodes_editor``` and ```demo/bin``` folders into your project, then in the ```Project | Project Settings | Plugins``` enable the plugin "Flow Nodes Editor"

# Basic Usage

In a scene 3D:

* Create a new node of type FlowGraphNode3D
* Click on the 'Data Flow' panel that has appeared in the right panel of the Godot Editor.
* Press Shit+A or Right click to make the "Add Node..." popup appear.
* Select one node. For example ```Grid```
* Press 'D' to visualize in the 3D scenes the points as white boxes
* Tweak parameters of the selected node, like the number of elements in the grid node, or the Size

# Features

* +32 nodes including:
    - Sampling splines (contout and interior)
    - Sampling meshes
    - CSG operations with points sets
    - Spawn meshes/full scenes with customized parameters
    - Expressions evaluation
    - Partition / Reduce / Merge / Sort
    - Ray cast the scene to query and place points
    - Match and Set to assign custom assets to the points
    - Change point distribution
* Grid Base Data Visualization and 3D Debug
* Flow Graphs are godot resources with optional inputs

# Platforms
    
Precompiled versions of the plugin are provided for Windows and OSX platforms. But it should compile without problems in the Linux.

The tool is an editor tool, so it should works where the editor works. Most of the code is currently gdscript, except for wrappers clases to implement KDTrees (from https://github.com/jlblancoc/nanoflann) and RTrees (from https://github.com/nushoin/RTree)

# Roadmap

See the [file](demo/addons/flow_nodes_editor/README.md) 

# Build From Sources

    $ git submodule update --init
    $ scons

