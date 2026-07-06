#!/usr/bin/env bash
set -Eeuo pipefail

OLYMPUS_DIR="${OLYMPUS_DIR:-$HOME/olympus}"
OLYMPUS_REPO="${OLYMPUS_REPO:-https://github.com/Aruuni/olympus.git}"
OLYMPUS_INSTALL_MARKER="${OLYMPUS_INSTALL_MARKER:-$OLYMPUS_DIR/.olympus_build_complete}"

APT_PACKAGES=(
    build-essential
    python3.11
    python3.11-dev
    python3.11-venv
    python3.8
    python3.8-dev
    python3.8-venv
)

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

olympus_is_available() {
    [[ -f "$OLYMPUS_DIR/build.sh" && -f "$OLYMPUS_INSTALL_MARKER" ]]
}

install_system_packages_if_needed() {
    local missing=()
    local package
    local sudo_cmd=()

    command -v apt-get >/dev/null 2>&1 || return 0
    command -v dpkg-query >/dev/null 2>&1 || return 0

    for package in "${APT_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
            missing+=("$package")
        fi
    done

    ((${#missing[@]} == 0)) && return 0

    if ((EUID != 0)); then
        command -v sudo >/dev/null 2>&1 || fail "Missing packages for Olympus: ${missing[*]}; sudo is required to install them"
        sudo_cmd=(sudo)
    fi

    say "Installing Ubuntu packages required by Olympus: ${missing[*]}"
    "${sudo_cmd[@]}" apt-get update
    "${sudo_cmd[@]}" apt-get install -y "${missing[@]}"
}

require_build_python() {
    command -v python3.11 >/dev/null 2>&1 || fail "Olympus build.sh requires python3.11"
    command -v python3.8 >/dev/null 2>&1 || fail "Olympus build.sh requires python3.8"
}

main() {
    local make_jobs="${MAKE_JOBS:-$(detect_make_jobs)}"

    if olympus_is_available; then
        say "Olympus is already built at $OLYMPUS_DIR"
        exit 0
    fi

    if [[ -e "$OLYMPUS_DIR" && ! -d "$OLYMPUS_DIR/.git" ]]; then
        fail "$OLYMPUS_DIR already exists but does not look like an Olympus git checkout"
    fi

    if [[ ! -d "$OLYMPUS_DIR" ]]; then
        say "Cloning Olympus into $OLYMPUS_DIR"
        git clone "$OLYMPUS_REPO" "$OLYMPUS_DIR"
    else
        say "Using existing Olympus checkout at $OLYMPUS_DIR"
    fi

    [[ -f "$OLYMPUS_DIR/build.sh" ]] || fail "Olympus build.sh is missing in $OLYMPUS_DIR"

    install_system_packages_if_needed
    require_build_python

    say "Building Olympus with $make_jobs parallel make jobs"
    cd "$OLYMPUS_DIR"
    MAKEFLAGS="-j$make_jobs ${MAKEFLAGS:-}" bash ./build.sh
    touch "$OLYMPUS_INSTALL_MARKER"

    say "Olympus installation verified"
}

main "$@"
