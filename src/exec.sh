#!/bin/bash

set -u # all environment vars must be set

# usage: print_usage matched_path
print_exec_usage_and_exit() {
	usage_str="Usage: adw ${1//\// } {"
	for target in "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$1"/*; do
		if [ ! -d "$target" ]; then
			continue
		fi
		usage_str="${usage_str}$(basename "$target")|"
	done
	usage_str="${usage_str%|}} [...]"
	echo "$usage_str"
	exit 1
}

# usage: check_deps matched_path
check_deps() {
	if [ ! -d "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$1/$ADW_DNAME_DEPS" ]; then
		return # no dependency requirement
	fi
	unsat_deps=()
	for dep in "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$1/$ADW_DNAME_DEPS"/*; do
		if [ ! -f "$dep/$ADW_FNAME_DONE" ]; then
			unsat_deps+=("$dep")
		fi
	done
	if [ ${#unsat_deps[@]} -gt 0 ]; then
		echo "ADW: Execution rejected: $matched_path"
		echo "  Dependencies unsatisfied:"
		for dep in "${unsat_deps[@]}"; do
			dep="$(basename "$dep")"
			echo "    - ${dep//://}"
		done
		exit 1
	fi
}

# variables $pred, $matched_path, and $cmd_path must be set
try_exec() {
	check_deps "${matched_path:?}"
	cmd_header=$(head -n 1 "${cmd_path:?}") # first line is always "#!/bin/bash"
	if [ ! $# = "0" ] && [[ "$cmd_header" != *"adw_pass_unmatched_args"* ]]; then
		echo "ADW: Unexpected arguments: $*"
		exit 1
	fi
	# Trash DONE signal files
	if [[ "$cmd_header" == *"adw_is_exclusive"* ]]; then
		find "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/${pred:?}" -name "$ADW_FNAME_DONE" -delete
	fi
	rm -rf "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/${matched_path:?}/$ADW_FNAME_DONE"

	nonce="$RANDOM"
	# write start log
	printf "%s %s %s   _ %5d %s\n" "+" "$(date '+%F %T')" \
		"$(git rev-parse --short HEAD 2>/dev/null || echo "-------")" \
		"$nonce" "$*" \
		>>"$ADW_PROJ_ROOT_DIR/$ADW_PROJ_LOG"

	bash "${cmd_path:?}" "$@"
	ret=$?
	if [ $ret = 0 ]; then
		touch "${ADW_PROJ_ROOT_DIR:?}/$ADW_PROJ_CMDS_DIR/${matched_path:?}/$ADW_FNAME_DONE"
	fi
	# write finish log
	printf "%s %s %s %3d %5d %s\n" "-" "$(date '+%F %T')" \
		"$(git rev-parse --short HEAD 2>/dev/null || echo "-------")" \
		"$ret" "$nonce" "$*" \
		>>"$ADW_PROJ_ROOT_DIR/$ADW_PROJ_LOG"
	exit $ret
}

adw_exec() {
	if [ $# = 0 ] && [ ! -d "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR" ]; then
		echo "ADW Internel Error: exec.sh is called incorrectly: $ADW_PROJ_CMDS_DIR not found"
		exit 1
	fi

	# first handle predicate match
	if [ $# = 0 ] || [ ! -d "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$1" ]; then
		if [ -f "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$ADW_FNAME_HELP" ]; then
			print_adw_usage # defined in bin/adw
			echo ""
			echo "PREDICATE:"
			cat "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$ADW_FNAME_HELP"
		else
			echo "ADW Internel Error: exec.sh is called incorrectly: $ADW_PROJ_CMDS_DIR/$ADW_FNAME_HELP not found"
		fi
		exit 1
	fi

	pred="$1"
	matched_path="$pred"
	args_left=("${@:2}")

	while true; do
		cmd_path="$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$matched_path/$ADW_FNAME_CMD"
		if [ -f "$cmd_path" ]; then
			# args_left[@] is tricky here since args_left could be an empty array
			# ref: https://stackoverflow.com/questions/7577052/bash-empty-array-expansion-with-set-u
			try_exec "${args_left[@]+"${args_left[@]}"}"
		fi

		if [ ${#args_left[@]} -gt 0 ]; then
			next_matched="$matched_path/${args_left[0]}"
			if [ ! -d "$ADW_PROJ_ROOT_DIR/$ADW_PROJ_CMDS_DIR/$next_matched" ]; then
				print_exec_usage_and_exit "$matched_path"
			fi
			matched_path="$next_matched"
			args_left=("${args_left[@]:1}")
		else
			print_exec_usage_and_exit "$matched_path"
		fi
	done
}
