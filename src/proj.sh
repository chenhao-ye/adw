#!/bin/bash

# shellcheck disable=SC1091
source "$ADW_HOME/lib/lib.sh"

set -u # all variables must be set

proj_init() {
	if [ $# -gt 1 ]; then print_adw_usage_and_exit; fi
	if [ $# = 1 ] && [ ! "$1" = "-f" ]; then print_adw_usage_and_exit; fi
	if [ -e "$ADW_PROJ_CTRL_DIR" ]; then
		if [ $# = 1 ] && [ "$1" = "-f" ]; then
			rm -rf "$ADW_PROJ_CMDS_DIR"
		else
			echo "This project has already been initialized!"
			echo "Use \"-f\" to force reinitialize."
			return 1
		fi
	fi
	if [ ! -f "$ADW_PROJ_CONFIG" ]; then
		echo "Fail to initialize the project: $ADW_PROJ_CONFIG not found"
		return 1
	fi
	## Ideally, these files should be put into .gitignore
	## but we decided to let user to do this instead of automating it...
	# if [ -f .gitignore ]; then
	# 	adw_append_if_not_exist "$ADW_PROJ_CTRL_DIR" .gitignore
	# 	adw_append_if_not_exist "$ADW_PROJ_DATA_DIR" .gitignore
	# fi
	mkdir "$ADW_PROJ_CTRL_DIR" && mkdir -p "$ADW_PROJ_DATA_DIR" &&
		echo "ADW: Init project $(basename "$PWD") successfully"
}

proj_load() {
	if [ ! $# = 0 ]; then print_adw_usage_and_exit; fi
	if [ ! -d "$ADW_PROJ_CTRL_DIR" ]; then
		echo "Detect this project has not been initialized"
		echo "Try \`adw proj init\` first"
		return 1
	fi
	if [ ! -f "$ADW_PROJ_CONFIG" ]; then
		echo "Fail to load the project: $ADW_PROJ_CONFIG not found"
		return 1
	fi
	if [ -d "$ADW_PROJ_CMDS_DIR" ]; then
		echo "Detect this project has been loaded"
		echo "Reloading..."
	fi
	rm -rf "$ADW_PROJ_CMDS_DIR" "$ADW_PROJ_ENV" "$ADW_PROJ_LOG"
	mkdir "$ADW_PROJ_CMDS_DIR"
	# yaml parsing and code generation is too complicated
	# offload to a python script instead
	python3 "$ADW_HOME/src/load.py" &&
		echo "ADW: Load project $(basename "$PWD") successfully"
}

proj_log() {
	if [ $# -gt 1 ]; then print_adw_usage_and_exit; fi
	if [ ! -f "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_LOG" ]; then
		echo "ADW: Log is empty..."
		return
	fi
	if [ $# = 0 ]; then
		python3 "$ADW_HOME/src/log.py"
	elif [ "$1" = "--less" ]; then
		python3 "$ADW_HOME/src/log.py" | less
	elif [ "$1" = "--vim" ]; then
		python3 "$ADW_HOME/src/log.py" | vim -
	else
		print_adw_usage_and_exit
	fi
}

proj_list() {
	if [ ! $# = 0 ]; then print_adw_usage_and_exit; fi
	for name in "$ADW_LINKS"/*; do
		if [ -L "$name" ]; then
			printf "%12s -> %s\n" "$(basename "$name")" "$(readlink "$name")"
		fi
	done
}

proj_add() {
	if [ ! $# = 0 ]; then print_adw_usage_and_exit; fi
	if [ ! -d "$ADW_PROJ_CTRL_DIR" ]; then
		echo "Detect this project has not been initialized"
		echo "Try \`adw proj init\` first"
		return 1
	fi
	base_name="$(basename "$PWD")"
	name="$base_name"
	cnt=0
	while [ -e "$ADW_LINKS/$name" ]; do
		cnt=$((cnt + 1))
		name=$base_name-$cnt
	done
	ln -s "$PWD" "$ADW_LINKS/$name" &&
		echo "ADW: Add project $name successfully"
}

proj_remove() {
	if [ ! $# = 1 ]; then print_adw_usage_and_exit; fi
	if [ ! -L "$ADW_LINKS/$1" ]; then
		echo "Project $1 not found!"
		return 1
	fi
	unlink "$ADW_LINKS/$1" &&
		echo "ADW: Remove project $1 successfully"
}

proj_global() {
	if [ ! $# = 1 ]; then print_adw_usage_and_exit; fi
	if [ "$1" = "-u" ]; then
		rm -rf "$ADW_GLOBAL_LINK"
	else
		if [ -d "$ADW_LINKS/$1" ] && [ -L "$ADW_LINKS/$1" ]; then
			rm -rf "$ADW_GLOBAL_LINK"
			ln -s "$(readlink "$ADW_LINKS/$1")" "$ADW_GLOBAL_LINK"
		else
			echo "Fails to find $1 in managed projects"
			return 1
		fi
	fi
}

proj_cleanup() {
	if [ ! $# = 0 ]; then print_adw_usage_and_exit; fi
	for name in "$ADW_LINKS"/*; do
		if [ -L "$name" ]; then
			if [ ! -d "$(readlink "$name")" ]; then
				echo "Removing $name..."
				rm -rf "$name"
			fi
		fi
	done
}

adw_proj() {
	case $1 in
	init)
		proj_init "${@:2}"
		;;
	load)
		proj_load "${@:2}"
		;;
	log)
		load_proj # defined in bin/adw
		proj_log "${@:2}"
		;;
	list)
		proj_list "${@:2}"
		;;
	add)
		proj_add "${@:2}"
		;;
	remove)
		proj_remove "${@:2}"
		;;
	global)
		proj_global "${@:2}"
		;;
	cleanup)
		proj_cleanup "${@:2}"
		;;
	*)
		print_adw_usage_and_exit
		;;
	esac
	return $?
}
