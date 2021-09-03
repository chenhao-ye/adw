#!/bin/bash

set -e

# shellcheck disable=SC1091
source env/env.sh

# The home of wizards :)
export ADW_HOME="$HOME/.adwarts"

print_usage_and_exit() {
	echo "Usage: $0 [-u]"
	echo "  Install/uninstall ADW."
	echo "  If not argument provided, install ADW to $ADW_HOME"
	echo "  If \`-u\` is provided, uninstall ADW from $ADW_HOME"
}

if [ $# -gt 1 ]; then
	print_usage_and_exit
fi

if [ $# = 1 ]; then
	if [ "$1" = "-u" ]; then
		if [ -d "$ADW_HOME" ]; then
			rm -rf "$ADW_HOME"
			echo "Uninstall ADW successfully."
			exit 0
		else
			echo "No installed ADW detected. Do nothing..."
			exit 1
		fi
	else
		print_usage_and_exit
	fi
fi

if [ -d "$ADW_HOME" ]; then
	echo "ADW has already installed, please uninstall it first."
	exit 1
fi

rm -rf "$ADW_HOME"
cp -rf ./ "$ADW_HOME"
mkdir -p "$ADW_LINKS"

# required to parse yaml config
pip3 install strictyaml

echo "To add \`adw\` to your path, add these two lines your .bashrc/.zshrc"
# shellcheck disable=SC2016
echo '  export ADW_HOME="$HOME/.adwarts"'
# shellcheck disable=SC2016
echo '  export PATH="$PATH:$ADW_HOME/bin"'
