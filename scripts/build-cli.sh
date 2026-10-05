#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
moon build --target native --release cmd/main
mkdir -p dist
if [ -f _build/native/release/build/cmd/main/main.exe ]; then
  cp _build/native/release/build/cmd/main/main.exe dist/moon-dbc
else
  cp _build/native/release/build/cmd/main/main dist/moon-dbc
fi
chmod +x dist/moon-dbc
