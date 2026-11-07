#!/usr/bin/env bash
# Builds the libmpv plugin the player needs. Run it again if a Qt or mpv update
# stops the player from starting.
# Needs: cmake, ninja, gcc, qt6-base, qt6-declarative, mpv.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build="${XDG_CACHE_HOME:-$HOME/.cache}/mainstream-player/build"
dest="$HOME/.local/lib/mainstream-player/qml/MpvPlayer"

cmake -S "$here/plugin" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$build"
mkdir -p "$dest"
cp "$build/qml/MpvPlayer/libmpvplayer.so" "$build/qml/MpvPlayer/qmldir" "$build/qml/MpvPlayer/mpvplayer.qmltypes" "$dest/"
echo "Installed to $dest"
