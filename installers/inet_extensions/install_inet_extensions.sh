#!/usr/bin/env bash
set -Eeuo pipefail

OMNET_DIR="${OMNET_DIR:-$HOME/omnetpp}"
SAMPLES_DIR="${SAMPLES_DIR:-$OMNET_DIR/samples}"

REPOS=(
    "tcpPaced:https://github.com/Avian688/tcpPaced.git"
    "tcpGoodputApplications:https://github.com/Avian688/tcpGoodputApplications.git"
    "cubic:https://github.com/Avian688/cubic.git"
    "leosatellites:https://github.com/Avian688/leosatellites.git"
    "orbtcpExperiments:https://github.com/Avian688/orbtcpExperiments.git"
    "os3:https://github.com/Avian688/os3.git"
    "orbtcp:https://github.com/Avian688/orbtcp.git"
    "bbr:https://github.com/Avian688/bbr.git"
)

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

project_is_built() {
    local dir="$1"
    [[ -f "$dir/Makefile" ]] || return 1
    find "$dir" -path '*/out/*' -type f \( -name '*.so' -o -name '*.dll' -o -name '*.dylib' \) -print -quit | grep -q .
}

clone_if_needed() {
    local name="$1"
    local repo="$2"
    local dir="$SAMPLES_DIR/$name"

    if [[ -d "$dir/.git" ]]; then
        say "$name already exists at $dir"
        return 0
    fi

    if [[ -e "$dir" ]]; then
        fail "$dir already exists but does not look like a git checkout"
    fi

    say "Cloning $name into $dir"
    git clone "$repo" "$dir"
}

build_project() {
    local name="$1"
    local dir="$SAMPLES_DIR/$name"

    [[ -f "$dir/Makefile" ]] || {
        say "$name has no top-level Makefile; skipping build"
        return 0
    }

    if project_is_built "$dir"; then
        say "$name already appears to be built"
        return 0
    fi

    say "Building $name"
    bash -lc "source '$OMNET_DIR/setenv' >/dev/null 2>&1 && cd '$dir' && make makefiles && make"
}

main() {
    omnet_is_available || fail "OMNeT++ must be installed and sourceable at $OMNET_DIR before installing INET extensions"
    [[ -d "$SAMPLES_DIR" ]] || fail "OMNeT++ samples directory not found at $SAMPLES_DIR"

    local item
    local name
    local repo

    for item in "${REPOS[@]}"; do
        name="${item%%:*}"
        repo="${item#*:}"
        clone_if_needed "$name" "$repo"
    done

    for item in "${REPOS[@]}"; do
        name="${item%%:*}"
        build_project "$name"
    done

    say "INET extension repositories installed"
}

main "$@"
