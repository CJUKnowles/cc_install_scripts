#!/usr/bin/env bash
set -Eeuo pipefail

OMNET_DIR="${OMNET_DIR:-$HOME/omnetpp}"
INET_DIR="${INET_DIR:-$OMNET_DIR/samples/inet4.5}"
INET_REPO="${INET_REPO:-https://github.com/Avian688/inet4.5.git}"

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

inet_is_available() {
    [[ -f "$INET_DIR/setenv" && -f "$INET_DIR/Makefile" ]] || return 1
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" bash -lc \
        'source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" && source setenv >/dev/null 2>&1'
    find "$INET_DIR" -type f \( -name 'libINET.so' -o -name 'libINET.dylib' -o -name 'libINET.dll' \) -print -quit | grep -q .
}

main() {
    local make_jobs="${MAKE_JOBS:-$(detect_make_jobs)}"

    omnet_is_available || fail "OMNeT++ must be installed and sourceable at $OMNET_DIR before installing INET"
    [[ -d "$OMNET_DIR/samples" ]] || fail "OMNeT++ samples directory not found at $OMNET_DIR/samples"

    if inet_is_available; then
        say "INET is already installed and sourceable at $INET_DIR"
        exit 0
    fi

    if [[ -e "$INET_DIR" && ! -d "$INET_DIR/.git" ]]; then
        fail "$INET_DIR already exists but does not look like an INET git checkout"
    fi

    if [[ ! -d "$INET_DIR" ]]; then
        say "Cloning INET into $INET_DIR"
        git clone "$INET_REPO" "$INET_DIR"
    else
        say "Using existing INET checkout at $INET_DIR"
    fi

    cd "$INET_DIR"

    say "Installing INET Python requirements"
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" bash -lc \
        'source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" &&
         python3 -m pip install -r python/requirements.txt'

    say "Generating INET makefiles"
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" MAKE_JOBS="$make_jobs" bash -lc \
        'export MAKEFLAGS="-j$MAKE_JOBS ${MAKEFLAGS:-}" &&
         source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" && source setenv >/dev/null 2>&1 &&
         make -j"$MAKE_JOBS" makefiles'

    say "Building INET with $make_jobs parallel jobs"
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" MAKE_JOBS="$make_jobs" bash -lc \
        'export MAKEFLAGS="-j$MAKE_JOBS ${MAKEFLAGS:-}" &&
         source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" && source setenv >/dev/null 2>&1 &&
         make -j"$MAKE_JOBS"'

    if ! inet_is_available; then
        fail "INET build finished, but '$INET_DIR/setenv' could not be sourced"
    fi

    say "INET installation verified"
}

main "$@"
