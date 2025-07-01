#!/usr/bin/env python
import os
import sys

env = SConscript("godot-cpp/SConstruct")

# For reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=["plugins/"])
common_sources = Glob("plugin/*.cpp")

if env["platform"] == "macos":

    # Add MacOS frameworks
    frameworks = [ 
                 #   'AuthenticationServices'
                 #, 'StoreKit'
                 ]
    for framework in frameworks:
        env.Append(LINKFLAGS=['-framework', framework])

    library = env.SharedLibrary(
        "demo/bin/libflow.{}.{}.framework/libflow.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=common_sources,
    )

else:
    env.Append(CFLAGS=["/std:c11"])
    library = env.SharedLibrary(
        "demo/bin/libflow{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=common_sources,
    )

Default(library)
