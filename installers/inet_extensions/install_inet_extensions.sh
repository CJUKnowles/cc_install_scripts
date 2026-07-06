#!/usr/bin/env bash
set -Eeuo pipefail

OMNET_DIR="${OMNET_DIR:-$HOME/omnetpp}"
SAMPLES_DIR="${SAMPLES_DIR:-$OMNET_DIR/samples}"
INET_DIR="${INET_DIR:-$SAMPLES_DIR/inet4.5}"
OS3_DIR="${OS3_DIR:-$SAMPLES_DIR/os3}"

REPOS=(
    "tcpPaced:https://github.com/Avian688/tcpPaced.git"
    "tcpGoodputApplications:https://github.com/Avian688/tcpGoodputApplications.git"
    "cubic:https://github.com/Avian688/cubic.git"
    "os3:https://github.com/Avian688/os3.git"
    "leosatellites:https://github.com/Avian688/leosatellites.git"
    "orbtcpExperiments:https://github.com/Avian688/orbtcpExperiments.git"
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

APT_PACKAGES=(
    pkg-config
    libcurl4-openssl-dev
    libigraph-dev
    libxml2-dev
    zlib1g-dev
    libgmp-dev
    libblas-dev
    libglpk-dev
    liblapack-dev
    libarpack2-dev
)

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
    [[ -f "$INET_DIR/setenv" && -f "$INET_DIR/src/libINET.so" ]] || return 1
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" bash -lc \
        'source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" && source setenv >/dev/null 2>&1'
}

expected_project_library() {
    local name="$1"
    local dir="$SAMPLES_DIR/$name"

    printf '%s/src/lib%s.so\n' "$dir" "$name"
}

project_is_built() {
    local name="$1"
    local dir="$SAMPLES_DIR/$name"

    [[ -f "$dir/Makefile" ]] || return 1
    [[ -d "$dir/src" ]] || return 1
    [[ -f "$(expected_project_library "$name")" ]]
}

cubic_needs_artifact_cleanup() {
    [[ "$1" == "cubic" ]]
}

project_needs_system_packages() {
    [[ "$1" == "os3" || "$1" == "leosatellites" ]]
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

install_system_packages_if_needed() {
    local name="$1"
    local missing=()
    local package
    local sudo_cmd=()

    project_needs_system_packages "$name" || return 0
    command -v apt-get >/dev/null 2>&1 || return 0
    command -v dpkg-query >/dev/null 2>&1 || return 0

    for package in "${APT_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
            missing+=("$package")
        fi
    done

    ((${#missing[@]} == 0)) && return 0

    if ((EUID != 0)); then
        command -v sudo >/dev/null 2>&1 || fail "Missing packages for $name: ${missing[*]}; sudo is required to install them"
        sudo_cmd=(sudo)
    fi

    say "Installing Ubuntu packages required by $name: ${missing[*]}"
    "${sudo_cmd[@]}" apt-get update
    "${sudo_cmd[@]}" apt-get install -y "${missing[@]}"
}

clean_tracked_build_artifacts() {
    local name="$1"
    local dir="$SAMPLES_DIR/$name"

    cubic_needs_artifact_cleanup "$name" || return 0
    [[ -d "$dir/.git" ]] || return 0

    say "Removing stale tracked build artifacts from $name"
    git -C "$dir" ls-files -z -- '*.o' '*.so' '*.dll' '*.dylib' '*_m.cc' '*_m.h' |
        while IFS= read -r -d '' file; do
            rm -f "$dir/$file"
        done
    rm -rf "$dir/out"
}

pkg_config_flags() {
    local package="$1"
    shift

    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists "$package"; then
        pkg-config "$@" "$package"
    fi
}

header_include_flag() {
    local header="$1"
    shift
    local dir

    for dir in "$@"; do
        if [[ -f "$dir/$header" ]]; then
            printf ' -I%s' "$dir"
            return 0
        fi
    done
}

generate_makefiles() {
    local name="$1"
    local dir="$SAMPLES_DIR/$name"
    local curl_cflags
    local curl_libs
    local igraph_cflags
    local igraph_libs

    [[ -d "$dir/src" ]] || return 0

    if [[ "$name" == "os3" ]]; then
        curl_cflags="$(pkg_config_flags libcurl --cflags)"
        curl_libs="$(pkg_config_flags libcurl --libs)"
        curl_cflags+=$(header_include_flag curl.h \
            /usr/include/x86_64-linux-gnu/curl \
            /usr/include/curl \
            /usr/local/include/curl \
            /opt/homebrew/opt/curl/include/curl \
            /opt/local/include/curl)

        say "Generating $name makefiles with INET and curl support"
        OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" PROJECT_DIR="$dir" PROJECT_NAME="$name" CURL_CFLAGS="$curl_cflags" CURL_LIBS="${curl_libs:- -lcurl}" bash -lc \
            'source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
             cd "$INET_DIR" && source setenv >/dev/null 2>&1 &&
             cd "$PROJECT_DIR/src" &&
             opp_makemake -f --make-so --deep -o "$PROJECT_NAME" -I"$INET_DIR/src" $CURL_CFLAGS -L"$INET_DIR/src" $CURL_LIBS -lINET'
        return 0
    fi

    if [[ "$name" == "leosatellites" ]]; then
        [[ -d "$OS3_DIR/src" ]] || fail "OS3 must be installed at $OS3_DIR before building leosatellites"

        igraph_cflags="$(pkg_config_flags igraph --cflags)"
        igraph_libs="$(pkg_config_flags igraph --libs)"

        say "Generating $name makefiles with INET, OS3, and igraph support"
        OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" OS3_DIR="$OS3_DIR" PROJECT_DIR="$dir" PROJECT_NAME="$name" IGRAPH_CFLAGS="${igraph_cflags:- -I/usr/include/igraph}" IGRAPH_LIBS="${igraph_libs:- -ligraph}" bash -lc \
            'source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
             cd "$INET_DIR" && source setenv >/dev/null 2>&1 &&
             cd "$PROJECT_DIR/src" &&
             opp_makemake -f --make-so --deep -o "$PROJECT_NAME" -DINET_IMPORT -I"$INET_DIR/src" -I"$OS3_DIR/src" $IGRAPH_CFLAGS -L"$INET_DIR/src" -L"$OS3_DIR/src" $IGRAPH_LIBS -lINET -los3'
        return 0
    fi

    say "Generating $name makefiles with INET support"
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" PROJECT_DIR="$dir" PROJECT_NAME="$name" bash -lc \
        'source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" && source setenv >/dev/null 2>&1 &&
         cd "$PROJECT_DIR/src" &&
         opp_makemake -f --make-so --deep -o "$PROJECT_NAME" -I"$INET_DIR/src" -L"$INET_DIR/src" -lINET'
}

build_project() {
    local name="$1"
    local dir="$SAMPLES_DIR/$name"
    local make_jobs="${MAKE_JOBS:-$(detect_make_jobs)}"

    [[ -f "$dir/Makefile" ]] || {
        say "$name has no top-level Makefile; skipping build"
        return 0
    }

    install_system_packages_if_needed "$name"
    clean_tracked_build_artifacts "$name"

    if project_is_built "$name" && ! cubic_needs_artifact_cleanup "$name"; then
        say "$name already appears to be built"
        return 0
    fi

    generate_makefiles "$name"

    say "Building $name with $make_jobs parallel jobs"
    OMNET_DIR="$OMNET_DIR" INET_DIR="$INET_DIR" PROJECT_DIR="$dir" MAKE_JOBS="$make_jobs" bash -lc \
        'export MAKEFLAGS="-j$MAKE_JOBS ${MAKEFLAGS:-}" &&
         source "$OMNET_DIR/setenv" >/dev/null 2>&1 &&
         cd "$INET_DIR" && source setenv >/dev/null 2>&1 &&
         make -C "$PROJECT_DIR/src" -j"$MAKE_JOBS"'
}

main() {
    omnet_is_available || fail "OMNeT++ must be installed and sourceable at $OMNET_DIR before installing INET extensions"
    inet_is_available || fail "INET must be installed and built at $INET_DIR before installing INET extensions"
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
