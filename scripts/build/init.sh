#!/bin/sh
set -e
echo "Building project..."

: "${PROJECT:=default.project.json}"
echo "Using project file: $PROJECT"
export PROJECT
: "${SOURCEMAP:=sourcemap.json}"
echo "Using sourcemap path: $SOURCEMAP"
export SOURCEMAP
# : "${WALLY_PACKAGE_DIR:=Packages}"
# echo "Using Wally package directory: $WALLY_PACKAGE_DIR"
# export WALLY_PACKAGE_DIR

# if [ ! -d "$WALLY_PACKAGE_DIR" ]; then
# 	mkdir -p "$WALLY_PACKAGE_DIR"
# fi

rojo sourcemap "$PROJECT" --output "$SOURCEMAP"
echo "Build complete."

# sh scripts/build/wally-install.sh