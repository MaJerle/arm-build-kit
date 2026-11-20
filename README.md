# GCC ARM CMake Toolkit

Reusable CMake toolchain and compiler-flag files for building Cortex-M firmware with `arm-none-eabi-gcc`. 
Drop this folder into any CMake project.

## 1. Toolchain file (in your CMake preset)

Point `toolchainFile` at `compiler-gcc-arm-none-eabi.cmake` in your `CMakePresets.json`:

```json
{
    "configurePresets": [
        {
            "name": "default",
            "generator": "Ninja",
            "toolchainFile": "${sourceDir}/cmake/compiler-gcc-arm-none-eabi.cmake",
            "cacheVariables": {
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
            }
        }
    ]
}
```

This sets up `arm-none-eabi-gcc`/`g++`/`objcopy`/`size` and the base GCC flags.
For example `-fdata-sections -ffunction-sections -Wl,--gc-sections` and many others.

## 2. CPU file (in your `CMakeLists.txt`)

Pick the file matching your MCU's core and `include()` it **before** `add_executable()`.
It sets `CMAKE_C_FLAGS` / `CMAKE_CXX_FLAGS` / `CMAKE_ASM_FLAGS` (and their Debug/Release variants) with the correct `-mcpu` / `-mfpu` / `-mfloat-abi` for that core:

```cmake
# Include the compiler file for your core config
include(${CMAKE_CURRENT_LIST_DIR}/cmake/compiler-gcc-cortex-m4.cmake)

# Create executable
add_executable(${CMAKE_PROJECT_NAME})
add_....
```

| Core       | File                               | CMSE / TrustZone variant                 |
| ---------- | ---------------------------------- | ---------------------------------------- |
| Cortex-M0  | `compiler-gcc-cortex-m0.cmake`     | —                                        |
| Cortex-M0+ | `compiler-gcc-cortex-m0p.cmake`    | —                                        |
| Cortex-M3  | `compiler-gcc-cortex-m3.cmake`     | —                                        |
| Cortex-M4  | `compiler-gcc-cortex-m4.cmake`     | —                                        |
| Cortex-M7  | `compiler-gcc-cortex-m7.cmake`     | —                                        |
| Cortex-M23 | `compiler-gcc-cortex-m23.cmake`    | `compiler-gcc-cortex-m23-cmse.cmake`     |
| Cortex-M33 | `compiler-gcc-cortex-m33.cmake`    | `compiler-gcc-cortex-m33-cmse.cmake`     |
| Cortex-M55 | `compiler-gcc-cortex-m55.cmake`    | `compiler-gcc-cortex-m55-cmse.cmake`     |
| Cortex-M85 | `compiler-gcc-cortex-m85.cmake`    | `compiler-gcc-cortex-m85-cmse.cmake`     |

> Use the `-cmse` file only for a TrustZone secure-side build (adds `-mcmse`). A regular non-partitioned build, or a TrustZone non-secure build, uses the plain file.

## 3. Linker (in your `CMakeLists.txt`)

These files only configure the compiler. You still need to set your own linker script and link libraries with `target_link_options()`.

The part in `CMakeLists.txt` for linker

```cmake
target_link_options(${CMAKE_PROJECT_NAME} PRIVATE
    -T${CMAKE_CURRENT_LIST_DIR}/linker/your_linker_script.ld
    -Wl,-Map=${CMAKE_PROJECT_NAME}.map
    -Wl,--start-group
    -lc
    -lm
    -lstdc++
    -lsupc++
    -Wl,--end-group
    -Wl,--print-memory-usage
    -Wl,-z,max-page-size=8
)
```

You do **not** need to repeat `-mcpu`/`-mfpu`/`-mfloat-abi` here — the CPU file already put them in `CMAKE_C_FLAGS`, and CMake forwards those to the final link command automatically.

Useful linker extras, add only if your project needs them:
- `-u _printf_float --specs=nosys.specs` — `printf`/`scanf` float support with newlib
- `-Wl,-z,max-page-size=8` — fixes GNU ld over-aligning output sections (seen on some newer binutils/cores where the default page size otherwise forces `64kB` alignment that no linker script setting can override)

## 4. Example `CMakeLists.txt`

Full example project wiring the pieces above together. It assumes headers in `include/`, sources in `source/`, and a linker script `Linker.ld`, all next to the `CMakeLists.txt`. Macros, include paths and sources are collected into `symbols_SYMB`, `include_DIRS` and `sources_SRCS` variables and passed to the corresponding `target_*()` calls.

For the folder tree:

```
project/
|- cmake/
|- source/
|   - source.c
|   - startup.s
|   - ...
|- include/
|   - file.h
|   - ...
|- linker/
|   - linkerscript.ld
|- CMakeLists.txt
```

`CMakeLists.txt` becomes:

```cmake
cmake_minimum_required(VERSION 3.22)

project(example_project C CXX ASM)

# Include the compiler file for your core config
include(${CMAKE_CURRENT_LIST_DIR}/cmake/compiler-gcc-cortex-m4.cmake)

# Glob all sources in the "source" folder.
# Prefer listing files explicitly in real projects -- CMake can't see new/removed
# files added to a glob until you re-run configure -- but it's handy for a quick example.
file(GLOB_RECURSE sources_SRCS CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_LIST_DIR}/source/*.c
    ${CMAKE_CURRENT_LIST_DIR}/source/*.cpp
    ${CMAKE_CURRENT_LIST_DIR}/source/*.s
    ${CMAKE_CURRENT_LIST_DIR}/source/*.S
)

# Include paths
set(include_DIRS
    ${CMAKE_CURRENT_LIST_DIR}/include
)

# Preprocessor macros (no -D prefix -- CMake adds it)
set(symbols_SYMB
    MY_SYMB_1
    MY_SYMB_2
    "MY_SYMB_WITH_VALUE=10"
)

# Create executable
add_executable(${CMAKE_PROJECT_NAME})
target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${sources_SRCS})
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${include_DIRS})
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE ${symbols_SYMB})

# Configure the linker
target_link_options(${CMAKE_PROJECT_NAME} PRIVATE
    -T${CMAKE_CURRENT_LIST_DIR}/linker/linkerscript.ld
    -Wl,-Map=${CMAKE_PROJECT_NAME}.map
    -Wl,--start-group
    -lc
    -lm
    -lstdc++
    -lsupc++
    -Wl,--end-group
    -Wl,--print-memory-usage
    -Wl,-z,max-page-size=8
)
```

## 5. Docker build image

A ready-to-use build image is published to GitHub Container Registry for `linux/amd64` and `linux/arm64` (runs natively on Apple Silicon):

```
ghcr.io/majerle/arm-build-kit:latest     # rebuilt on every push to main
ghcr.io/majerle/arm-build-kit:v1.0.0     # one per GitHub release (also 1.0.0 and 1.0)
```

Pin a release tag in CI. Use `latest` only for trying things out.

What's inside:
- Arm GNU Toolchain `15.2.rel1` (`arm-none-eabi-*`) on `PATH`
- `cmake`, `ninja`, `make`, `git`, `clang-format`, `clang-tidy`, `cppcheck`
- Python 3.14 venv at `/opt/venv` (first on `PATH`) with a minimal base set from [pyproject.toml](pyproject.toml): intelhex, pycryptodome, elf-size-analyze, pyserial, numpy, matplotlib, ...
- `install-build-requirements` to add your project's own Python packages (see below)
- This repo's CMake files at `/opt/arm-build-kit/cmake`, exposed as `$ARM_BUILD_KIT_CMAKE_DIR`

To use the baked-in CMake files instead of vendoring a copy:

```json
"toolchainFile": "$env{ARM_BUILD_KIT_CMAKE_DIR}/compiler-gcc-arm-none-eabi.cmake"
```

```cmake
include($ENV{ARM_BUILD_KIT_CMAKE_DIR}/compiler-gcc-cortex-m4.cmake)
```

### Run locally

Mount the project at the same path inside the container so that the absolute paths CMake caches stay valid on both the host and the container:

```bash
docker run --rm -it -v "$PWD":"$PWD" -w "$PWD" --user "$(id -u):$(id -g)" -e HOME=/tmp \
    ghcr.io/majerle/arm-build-kit:latest \
    bash -c "cmake --preset default && cmake --build --preset default"
```

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/majerle/arm-build-kit:v1.0.0
    steps:
      - uses: actions/checkout@v4
      - run: install-build-requirements
      - run: cmake --preset default && cmake --build --preset default
```

### Dev container

```json
{
    "image": "ghcr.io/majerle/arm-build-kit:latest",
    "postCreateCommand": "install-build-requirements"
}
```

### Project-specific Python packages

The image ships only a small base set of Python packages. Put anything else your project needs into a `requirements-build.txt` in the project root:

```
protobuf==6.33.6
nanopb
grpcio-tools
```

It is installed into `/opt/venv` on top of the base set:
- `docker run`: automatically, by the image entrypoint, when the file exists in the working directory (`-w`).
- GitHub Actions `container:` jobs and dev containers: these bypass the entrypoint, so call `install-build-requirements` yourself (as in the examples above).

`install-build-requirements` looks for `$ARM_BUILD_KIT_REQUIREMENTS` (default `requirements-build.txt`) and does nothing if that file is missing. It also takes an explicit path: `install-build-requirements tools/requirements.txt`.

For heavy dependency sets you don't want to reinstall on every CI run, extend the image instead:

```dockerfile
FROM ghcr.io/majerle/arm-build-kit:v1.0.0
COPY requirements-build.txt /tmp/
RUN install-build-requirements /tmp/requirements-build.txt
```

### Updating the image

- Toolchain: change `ARM_TOOLCHAIN_VERSION` in the [Dockerfile](Dockerfile).
- Python packages: edit [pyproject.toml](pyproject.toml), run `uv lock`, and commit `uv.lock`.
- Push to `main` to update `latest`. Publish a GitHub release to create a versioned tag.

> The first publish creates a **private** package on GHCR. To let other projects pull it without logging in, set its visibility to public in the package settings.
