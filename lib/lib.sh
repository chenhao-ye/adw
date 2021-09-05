#!/bin/bash

# This script is design to be used by users
# To use this libary:
#     source "$ADW_LIB"
# All shell functions in this script will prefix with `adw` to avoid conflict

# append a string to a file if this line not already exists
# useful to make scripts idempotent
# usage: adw_append_if_not_exist line file
adw_append_if_not_exist() {
    if ! grep -qxF "${1:?}" "${2:?}"; then
        echo "${1:?}" >>"${2:?}"
    fi
}

# sudo version; useful for some system config files
adw_sudo_append_if_not_exist() {
    if ! sudo grep -qxF "${1:?}" "${2:?}"; then
        echo "${1:?}" | sudo tee -a "${2:?}" >/dev/null
    fi
}

# source a shell script if it exists
# usage: adw_source_if_exist file
adw_source_if_exist() {
    if [ -f "${1:?}" ]; then
        # shellcheck source=/dev/null
        source "${1:?}"
    fi
}

# usage: adw_assert_dir_exist dir
adw_assert_dir_exist() {
    if [ ! -d "${1:?}" ]; then
        echo "Directory not found: $1" >&2
        exit 1
    fi
}

# Create a directory with versioning, linked under project ADW_DATA and provide
# a "latest" reference
# NOTE: one should NOT call this function twice in a row with the same name,
#       which would lead to naming conflict. In such a case, instead of reporting an
#       error, we enforce a one-second slow down.
# usage:
# - data_dir=$(adw_mk_data_dir name) # create in CWD
# - data_dir=$(adw_mk_data_dir name path) # create under path
adw_mk_data_dir() {
    dir_path="${2:-$PWD}"
    latest_dir="$dir_path/DATA_${1:?}_latest"
    proj_data_dir="$ADW_PROJ_DATA_DIR/DATA_${1:?}"
    rm -rf "$latest_dir"
    rm -rf "$proj_data_dir"
    data_dir="$dir_path/DATA_${1:?}_$(git rev-parse --short HEAD 2>/dev/null || echo "-------")_$(date +%y-%m-%d-%H-%M-%S)"
    if [ -d "$data_dir" ]; then
        # This can only happen if two calls are too closed
        # We enforce slow down here
        sleep 1
    fi
    mkdir "$data_dir"
    ln -s "$data_dir" "$latest_dir"
    ln -s "$data_dir" "$proj_data_dir"
    echo "$data_dir"
}
