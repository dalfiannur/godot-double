#!/usr/bin/env bash
# Builds a double-precision Godot editor and Terrain3D for it, into dist/.
#   ./build.sh            # everything
#   ./build.sh godot      # only the editor
#   ./build.sh terrain3d  # only Terrain3D (needs the editor, for its API)
# Sources go to $SRC (default ~/.local/src) and are reused on later runs, so
# rebuilds are incremental. Needs git, a C++ toolchain and python3; scons is
# installed into its own venv if it isn't on PATH.
set -euo pipefail

GODOT_VERSION=4.7.2-stable
TERRAIN3D_VERSION=v1.0.2-stable
# godot-cpp master at the time of the first build: Terrain3D 1.0.2's own
# godot-cpp (4.4) can't generate bindings for Godot 4.7's API, and with its 4.4
# method hashes the double engine crashes on PhysicsServer3D.body_add_shape.
GODOT_CPP_COMMIT=e103d348c4b2d8df7b819126d855e19381cb9a87
JOBS=${JOBS:-$(nproc)}
SRC=${SRC:-$HOME/.local/src}

HERE=$(cd "$(dirname "$0")" && pwd)
DIST=$HERE/dist
GODOT_DIR=$SRC/godot-${GODOT_VERSION%-stable}
TERRAIN3D_DIR=$SRC/terrain3d-${TERRAIN3D_VERSION#v}-double
API_DIR=$SRC/godot-double-api
EDITOR=godot.linuxbsd.editor.double.x86_64

scons_cmd() {
    if command -v scons >/dev/null; then
        scons "$@"
        return
    fi
    if [ ! -x "$HOME/.local/opt/scons-venv/bin/scons" ]; then
        python3 -m venv "$HOME/.local/opt/scons-venv"
        "$HOME/.local/opt/scons-venv/bin/pip" install -q scons
    fi
    "$HOME/.local/opt/scons-venv/bin/scons" "$@"
}

build_godot() {
    if [ ! -d "$GODOT_DIR" ]; then
        git clone -c advice.detachedHead=false --depth 1 --branch "$GODOT_VERSION" \
            https://github.com/godotengine/godot.git "$GODOT_DIR"
    fi
    (cd "$GODOT_DIR" && scons_cmd platform=linuxbsd target=editor precision=double debug_symbols=no -j"$JOBS")
    mkdir -p "$DIST"
    cp "$GODOT_DIR/bin/$EDITOR" "$DIST/"
    echo "editor: $DIST/$EDITOR ($("$DIST/$EDITOR" --version))"
}

build_terrain3d() {
    if [ ! -x "$DIST/$EDITOR" ]; then
        echo "Build the editor first: ./build.sh godot" >&2
        exit 1
    fi
    # Bindings must match the engine exactly, double precision included.
    mkdir -p "$API_DIR"
    (cd "$API_DIR" && "$DIST/$EDITOR" --headless --dump-extension-api --dump-gdextension-interface >/dev/null 2>&1)
    if [ ! -d "$TERRAIN3D_DIR" ]; then
        git clone -c advice.detachedHead=false --depth 1 --branch "$TERRAIN3D_VERSION" \
            https://github.com/TokisanGames/Terrain3D.git "$TERRAIN3D_DIR"
        git -C "$TERRAIN3D_DIR" apply "$HERE/patches/terrain3d-1.0.2-godot-cpp-master.patch"
    fi
    if [ "$(git -C "$TERRAIN3D_DIR/godot-cpp" rev-parse HEAD 2>/dev/null)" != "$GODOT_CPP_COMMIT" ]; then
        rm -rf "$TERRAIN3D_DIR/godot-cpp"
        git init -q "$TERRAIN3D_DIR/godot-cpp"
        git -C "$TERRAIN3D_DIR/godot-cpp" fetch -q --depth 1 https://github.com/godotengine/godot-cpp.git "$GODOT_CPP_COMMIT"
        git -C "$TERRAIN3D_DIR/godot-cpp" -c advice.detachedHead=false checkout -q FETCH_HEAD
    fi
    for target in template_debug template_release; do
        (cd "$TERRAIN3D_DIR" && scons_cmd platform=linux target=$target precision=double \
            custom_api_file="$API_DIR/extension_api.json" -j"$JOBS")
    done
    mkdir -p "$DIST"
    for kind in debug release; do
        cp "$TERRAIN3D_DIR/project/addons/terrain_3d/bin/libterrain.linux.$kind.x86_64.so" \
            "$DIST/libterrain.linux.$kind.double.x86_64.so"
    done
    echo "terrain3d: $DIST/libterrain.linux.{debug,release}.double.x86_64.so"
}

case "${1:-all}" in
    godot) build_godot ;;
    terrain3d) build_terrain3d ;;
    all) build_godot; build_terrain3d ;;
    *) echo "usage: $0 [godot|terrain3d|all]" >&2; exit 2 ;;
esac
