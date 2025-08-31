# Install

Copy the ```addons/flow_nodes_editor``` and ```bin``` folders into your project, then in the ```Project | Project Settings | Plugins``` enable the plugin "Flow Nodes Editor"

# Basic Usage

In a scene 3D:

    * Create a new node of type FlowGraphNode3D
    * Click on the 'Data Flow' panel that has appeared in the right panel of the Godot Editor.
    * Press Shit+A or Right click to make the "Add Node..." popup appear.
    * Select one node. For example ```Grid```
    * Press 'D' to visualize in the 3D scenes the points as white boxes
    * Tweak parameters of the selected node, like the number of elements in the grid node, or the Size

# Build From Sources

    $ git submodule update --init
    $ scons

