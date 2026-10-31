#!/usr/bin/env bash
# Installs what build.sh made:
#   ./install.sh editor             # dist/ editor -> ~/.local/opt, `godot-double` on PATH
#   ./install.sh project <dir>      # double Terrain3D libraries into a Godot project
# The project gets libterrain.linux.{debug,release}.double.x86_64.so next to its
# own Terrain3D libraries, registered in terrain.gdextension under the
# "double" feature, so single-precision Godot keeps using the originals.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
DIST=$HERE/dist
EDITOR=godot.linuxbsd.editor.double.x86_64
OPT=$HOME/.local/opt/godot-double

install_editor() {
    mkdir -p "$OPT" "$HOME/.local/bin"
    cp "$DIST/$EDITOR" "$OPT/"
    ln -sf "$OPT/$EDITOR" "$HOME/.local/bin/godot-double"
    echo "godot-double -> $OPT/$EDITOR ($("$OPT/$EDITOR" --version))"
}

install_project() {
    local addon=$1/addons/terrain_3d
    if [ ! -f "$addon/terrain.gdextension" ]; then
        echo "No Terrain3D in $1 (expected $addon/terrain.gdextension)" >&2
        exit 1
    fi
    for kind in debug release; do
        cp "$DIST/libterrain.linux.$kind.double.x86_64.so" "$addon/bin/"
    done
    python3 - "$addon/terrain.gdextension" <<'EOF'
import sys
path = sys.argv[1]
text = open(path).read()
if "linux.double.debug.x86_64" in text:
    sys.exit(0)
anchor = 'linux.release.x86_64 = "res://addons/terrain_3d/bin/libterrain.linux.release.x86_64.so"\n'
if anchor not in text:
    sys.exit("Can't find the linux.release.x86_64 line in %s; add the double entries by hand" % path)
text = text.replace(anchor, anchor + (
    '; Double-precision Godot (the "double" feature): Terrain3D built with godot-cpp\n'
    '; precision=double (see godot-double/build.sh). The most specific matching key wins.\n'
    'linux.double.debug.x86_64 = "res://addons/terrain_3d/bin/libterrain.linux.debug.double.x86_64.so"\n'
    'linux.double.release.x86_64 = "res://addons/terrain_3d/bin/libterrain.linux.release.double.x86_64.so"\n'), 1)
open(path, "w").write(text)
EOF
    echo "Terrain3D double libraries installed in $addon"
}

case "${1:-}" in
    editor) install_editor ;;
    project) install_project "${2:?usage: $0 project <godot project dir>}" ;;
    *) echo "usage: $0 editor | project <godot project dir>" >&2; exit 2 ;;
esac
