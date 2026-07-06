#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OMNET_INSTALLER="$ROOT_DIR/installers/install_omnet.sh"
INET_INSTALLER="$ROOT_DIR/installers/install_inet.sh"
INET_EXT_INSTALLER="$ROOT_DIR/installers/inet_extensions/install_inet_extensions.sh"
RAYNET_INSTALLER="$ROOT_DIR/installers/install_raynet.sh"
OLYMPUS_INSTALLER="$ROOT_DIR/installers/install_olympus.sh"

say() {
    printf '\n==> %s\n' "$*"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local suffix
    local reply

    if [[ "$default" == "y" ]]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    while true; do
        read -r -p "$prompt $suffix " reply
        reply="${reply:-$default}"
        case "$reply" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) printf 'Please answer yes or no.\n' ;;
        esac
    done
}

run_installer() {
    local name="$1"
    local script="$2"

    if [[ ! -f "$script" ]]; then
        printf 'ERROR: installer not found: %s\n' "$script" >&2
        exit 1
    fi
    bash -n "$script"

    say "Installing $name"
    bash "$script"
}

main() {
    say "Congestion control research stack installer"
    printf 'This will install selected components in dependency order.\n'

    local install_omnet=false
    local install_inet=false
    local install_inet_extensions=false
    local install_raynet=false
    local install_olympus=false

    if ask_yes_no "Install OMNeT++?" "y"; then
        install_omnet=true
    fi
    if ask_yes_no "Install INET 4.5?" "y"; then
        install_inet=true
    fi
    if ask_yes_no "Install the INET extension repositories?" "y"; then
        install_inet_extensions=true
    fi
    if ask_yes_no "Install RayNet?" "y"; then
        install_raynet=true
    fi
    if ask_yes_no "Install Olympus?" "y"; then
        install_olympus=true
    fi

    $install_omnet && run_installer "OMNeT++" "$OMNET_INSTALLER"
    $install_inet && run_installer "INET 4.5" "$INET_INSTALLER"
    $install_inet_extensions && run_installer "INET extension repositories" "$INET_EXT_INSTALLER"
    $install_raynet && run_installer "RayNet" "$RAYNET_INSTALLER"
    $install_olympus && run_installer "Olympus" "$OLYMPUS_INSTALLER"

    say "Done"
}

main "$@"
