#!/usr/bin/env bash
set -Eeuo pipefail

OMNET_DIR="${OMNET_DIR:-$HOME/omnetpp}"
RAYNET_DIR="${RAYNET_DIR:-$HOME/raynet}"
RAYNET_REPO="${RAYNET_REPO:-https://github.com/CJUKnowles/raynet.git}"

say() {
    printf '\n==> %s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

omnet_is_available() {
    [[ -f "$OMNET_DIR/setenv" ]] || return 1
    bash -lc "source '$OMNET_DIR/setenv' >/dev/null 2>&1 && command -v omnetpp >/dev/null 2>&1"
}

raynet_is_available() {
    [[ -x "$RAYNET_DIR/build.sh" && -d "$RAYNET_DIR/.venv" ]]
}

main() {
    omnet_is_available || fail "OMNeT++ must be installed and sourceable at $OMNET_DIR before installing RayNet"

    if raynet_is_available; then
        say "RayNet is already installed at $RAYNET_DIR"
        exit 0
    fi

    if [[ -e "$RAYNET_DIR" && ! -d "$RAYNET_DIR/.git" ]]; then
        fail "$RAYNET_DIR already exists but does not look like a RayNet git checkout"
    fi

    if [[ ! -d "$RAYNET_DIR" ]]; then
        say "Cloning RayNet with submodules into $RAYNET_DIR"
        git clone --recurse-submodules -j8 "$RAYNET_REPO" "$RAYNET_DIR"
    else
        say "Using existing RayNet checkout at $RAYNET_DIR"
        git -C "$RAYNET_DIR" submodule update --init --recursive
    fi

    [[ -x "$RAYNET_DIR/build.sh" ]] || fail "RayNet build.sh is missing or not executable in $RAYNET_DIR"

    say "Building RayNet and initializing its Python environment"
    cd "$RAYNET_DIR"
    ./build.sh -i

    raynet_is_available || fail "RayNet build finished, but expected files were not found in $RAYNET_DIR"

    say "RayNet installation verified"
}

main "$@"
