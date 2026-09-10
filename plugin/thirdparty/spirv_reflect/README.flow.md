# SPIRV-Reflect vendoring note

This directory contains the minimal source distribution needed by the Flow
GDExtension to reflect compute-shader SPIR-V.

- Upstream: https://github.com/KhronosGroup/SPIRV-Reflect
- Commit: `3954c1e89a031cfb1724fa640be4e696558e6e8c`
- License: Apache-2.0 (see `LICENSE`)
- Vendored files: `spirv_reflect.c`, `spirv_reflect.h`, and the required
  `include/spirv/unified1/spirv.h` header.
