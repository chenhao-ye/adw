#!/bin/bash
# This script defines environments that would be exported to all ADW scripts
# If a name has potential to conflict with user-defined names, use "ADW_" prefix
# and capitalized.

# ADW_HOME should be set by environment or adw main script
export ADW_HOME="${ADW_HOME:=$HOME/.adwarts}"

export ADW_META="$ADW_HOME/meta"
export ADW_LINKS="$ADW_HOME/links"
export ADW_GLOBAL_LINK="$ADW_LINKS/ADW_GLOBAL"

# name of data directory within each project
# all relative to $ADW_PROJ_ROOT_DIR, only valid after ADW_PROJ_ROOT_DIR set
export ADW_PROJ_DATA_DIR="ADW_DATA" # visible to users
export ADW_PROJ_CTRL_DIR=".adw"
export ADW_PROJ_CMDS_DIR="$ADW_PROJ_CTRL_DIR/cmds"
export ADW_PROJ_ENV="$ADW_PROJ_CTRL_DIR/env"
export ADW_PROJ_LOG="$ADW_PROJ_CTRL_DIR/log"

# name of signal files/directories
# these names has potential to conflict wiith user-defined predicate/target name
# so always prefix with "ADW_"
export ADW_FNAME_DONE="ADW_DONE"
export ADW_FNAME_CMD="ADW_CMD"
export ADW_FNAME_HELP="ADW_HELP"
export ADW_DNAME_DEPS="ADW_DEPS"

# config file name to read when loading the project
export ADW_PROJ_CONFIG="adw.yaml"
