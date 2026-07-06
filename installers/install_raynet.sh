#!/usr/bin/env bash
set -Eeuo pipefail

OMNET_DIR="${OMNET_DIR:-$HOME/omnetpp}"
RAYNET_DIR="${RAYNET_DIR:-$HOME/raynet}"
RAYNET_REPO="${RAYNET_REPO:-https://github.com/CJUKnowles/raynet.git}"
RAYNET_BUILD_MARKER="${RAYNET_BUILD_MARKER:-$RAYNET_DIR/.raynet_build_revision}"

say() {
    printf '\n==> %s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

detect_make_jobs() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    else
        getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n'
    fi
}

omnet_is_available() {
    [[ -f "$OMNET_DIR/setenv" ]] || return 1
    OMNET_DIR="$OMNET_DIR" bash -lc 'source "$OMNET_DIR/setenv" >/dev/null 2>&1 && command -v omnetpp >/dev/null 2>&1'
}

raynet_is_available() {
    [[ -x "$RAYNET_DIR/build.sh" && -d "$RAYNET_DIR/.venv" ]] || return 1
    "$RAYNET_DIR/.venv/bin/python" -c 'import setuptools.build_meta' >/dev/null 2>&1
    [[ -f "$RAYNET_BUILD_MARKER" ]] || return 1
    cmp -s "$RAYNET_BUILD_MARKER" <(current_raynet_revision)
}

current_raynet_revision() {
    git -C "$RAYNET_DIR" rev-parse HEAD
    git -C "$RAYNET_DIR" submodule status --recursive
}

update_submodules() {
    say "Updating RayNet submodules"
    git -C "$RAYNET_DIR" submodule sync --recursive
    git -C "$RAYNET_DIR" submodule update --init --recursive
}

main() {
    local make_jobs="${MAKE_JOBS:-$(detect_make_jobs)}"

    omnet_is_available || fail "OMNeT++ must be installed and sourceable at $OMNET_DIR before installing RayNet"

    if [[ -e "$RAYNET_DIR" && ! -d "$RAYNET_DIR/.git" ]]; then
        fail "$RAYNET_DIR already exists but does not look like a RayNet git checkout"
    fi

    if [[ ! -d "$RAYNET_DIR" ]]; then
        say "Cloning RayNet with submodules into $RAYNET_DIR"
        git clone --recurse-submodules -j8 "$RAYNET_REPO" "$RAYNET_DIR"
    else
        say "Using existing RayNet checkout at $RAYNET_DIR"
    fi

    update_submodules

    if raynet_is_available; then
        say "RayNet is already installed at $RAYNET_DIR"
        exit 0
    fi

    [[ -x "$RAYNET_DIR/build.sh" ]] || fail "RayNet build.sh is missing or not executable in $RAYNET_DIR"

    say "Building RayNet with $make_jobs parallel make jobs and initializing its Python environment"
    cd "$RAYNET_DIR"
    MAKEFLAGS="-j$make_jobs ${MAKEFLAGS:-}" ./build.sh -i
    current_raynet_revision >"$RAYNET_BUILD_MARKER"

    raynet_is_available || fail "RayNet build finished, but expected files were not found in $RAYNET_DIR"

    say "RayNet installation verified"
}

main "$@"
