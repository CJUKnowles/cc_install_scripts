#!/usr/bin/env bash
set -Eeuo pipefail

OMNET_DIR="${OMNET_DIR:-$HOME/omnetpp}"
OMNET_REPO="${OMNET_REPO:-https://github.com/omnetpp/omnetpp.git}"

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

main() {
    if omnet_is_available; then
        say "OMNeT++ is already installed and sourceable at $OMNET_DIR"
        exit 0
    fi

    if [[ -e "$OMNET_DIR" && ! -d "$OMNET_DIR/.git" ]]; then
        fail "$OMNET_DIR already exists but does not look like an OMNeT++ git checkout"
    fi

    if [[ ! -d "$OMNET_DIR" ]]; then
        say "Cloning OMNeT++ into $OMNET_DIR"
        git clone "$OMNET_REPO" "$OMNET_DIR"
    else
        say "Using existing OMNeT++ checkout at $OMNET_DIR"
    fi

    cd "$OMNET_DIR"

    if [[ ! -f configure.user && -f configure.user.dist ]]; then
        say "Creating configure.user from configure.user.dist"
        cp configure.user.dist configure.user
    fi

    [[ -x ./install.sh ]] || fail "OMNeT++ install.sh is missing or not executable in $OMNET_DIR"

    say "Running OMNeT++ install.sh"
    ./install.sh

    if ! omnet_is_available; then
        fail "OMNeT++ install finished, but '$OMNET_DIR/setenv' did not expose the omnetpp command"
    fi

    say "OMNeT++ installation verified"
}

main "$@"
