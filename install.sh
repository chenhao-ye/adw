#!/bin/bash

set -e

# The home of wizards :)
export ADW_HOME="$HOME/.adwarts"
export ADW_REPO_URL="https://github.com/chenhao-ye/adw.git"

print_usage_and_exit() {
	echo "Usage: $0 [-u] [-p]"
	echo "  Install/uninstall ADW."
	echo "  If no argument provided, install ADW to $ADW_HOME"
	echo "  If \`-p\` is provided, pull ADW repository from $ADW_REPO_URL before install"
	echo "  If \`-u\` is provided, uninstall ADW from $ADW_HOME instead"
	echo "  \`-p\` is incompatible with \`-u\`; if both specified, the latter one will be ignored"
}

set_shrc() {
	for sh in bash zsh; do
		shrc="$HOME/.${sh}rc"
		if [ -f "$shrc" ]; then
			# shellcheck disable=SC2016
			echo 'export ADW_HOME="$HOME/.adwarts"' >> "$shrc"
			# shellcheck disable=SC2016
			echo 'export PATH="$PATH:$ADW_HOME/bin"' >> "$shrc"
		fi
	done
}

unset_shrc() {
	for sh in bash zsh; do
		shrc="$HOME/.${sh}rc"
		if [ -f "$shrc" ]; then
			# shellcheck disable=SC2016
			sed -i.bak '/^export ADW_HOME="\$HOME\/\.adwarts"$/d' "$shrc"
			# shellcheck disable=SC2016
			sed -i.bak '/^export PATH="\$PATH:\$ADW_HOME\/bin"$/d' "$shrc"
			rm -rf "$shrc.bak"
		fi
	done
}

do_uninstall() {
	if [ -d "$ADW_HOME" ]; then
		rm -rf "$ADW_HOME"
		unset_shrc
		echo "Uninstall ADW successfully."
		exit 0
	else
		echo "No installed ADW detected. Do nothing..."
		exit 1
	fi
}

check_installed() {
	if [ -d "$ADW_HOME" ]; then
		echo "ADW has already been installed. Do nothing..."
		exit 1
	fi
}

is_pull="0"

for arg in "$@"; do
	if [ "$arg" = "-u" ]; then
		do_uninstall
	elif [ "$arg" = "-p" ]; then
		is_pull="1"
	else
		print_usage_and_exit
	fi
done

# reject if already installed
check_installed

if [ "$is_pull" = "1" ]; then
	git clone "$ADW_REPO_URL" "$ADW_HOME"
else
	repo_path="$(dirname "$0")"
	if [ ! -d "$repo_path/bin" ] || [ ! -d "$repo_path/src" ] || [ ! -d "$repo_path/env" ]; then
		echo "ADW repository not found!"
		echo "Please use \`-p\` to pull the repository first"
		exit 1
	fi
	cp -rf "$repo_path" "$ADW_HOME"
fi

# required to parse yaml config
echo "Install dependency: strictyaml"
pip3 install strictyaml

cd "$ADW_HOME"
# shellcheck disable=SC1091
source env/env.sh

mkdir -p "$ADW_LINKS"
set_shrc
echo "Install ADW successfully"
