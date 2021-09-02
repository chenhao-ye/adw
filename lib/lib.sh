#!/bin/bash

# This script is design to be used by users
# To use this libary:
#   source "$ADW_HOME/lib/lib.sh"
# All shell functions in this script will prefix with `adw` to avoid conflict

# NOTE: it will also reject if variable is empty (zero length)
# usage: adw_assert_var_exist $var
adw_assert_var_exist() {
    if [ -z "$1" ]; then
        echo "Variable is not set: $1" >&2
        exit 1
    fi
}

# append a string to a file if this line not already exists
# Useful to make scripts idempotent
# usage: adw_append_if_not_exist line file
adw_append_if_not_exist() {
    adw_assert_var_exist "$1"
    adw_assert_var_exist "$2"
    if ! grep -qxF "$1" "$2"; then
        echo "$1" >>"$2"
    fi
}

# sudo version
adw_sudo_append_if_not_exist() {
    adw_assert_var_exist "$1"
    adw_assert_var_exist "$2"
    if ! sudo grep -qxF "$1" "$2"; then
        echo "$1" | sudo tee -a "$2" >/dev/null
    fi
}

# usage: adw_source_if_exist file
adw_source_if_exist() {
    adw_assert_var_exist "$1"
    if [ -f "$1" ]; then
        # shellcheck source=/dev/null
        source "$1"
    fi
}

# usage: adw_assert_dir_exist dir
adw_assert_dir_exist() {
    adw_assert_var_exist "$1"
    if [ ! -d "$1" ]; then
        echo "Directory not found: $1" >&2
        exit 1
    fi
}

# Create a directory with versioning, linked under project ADW_DATA and provide
# a "latest" reference
# NOTE: one should NOT call this function twice in a row with the same name,
#       which would lead to naming conflict. In such a case, instead of reporting an
#       error, we enforce a one-second slow down.
# usage: data_dir=$(adw_mk_data_dir name)
adw_mk_data_dir() {
    adw_assert_var_exist "$1"
    latest_dir="$PWD/DATA_${1}_latest"
    proj_data_dir="$ADW_PROJ_DATA_DIR/DATA_$1"
    rm -rf "$latest_dir"
    rm -rf "$proj_data_dir"
    data_dir="$PWD/DATA_$1_$(git rev-parse --short HEAD 2>/dev/null || echo "-------")_$(date +%y-%m-%d-%H-%M-%S)"
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
