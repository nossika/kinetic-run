#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

resolve_godot_bin() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		if [[ -x "$GODOT_BIN" ]]; then
			printf '%s\n' "$GODOT_BIN"
			return 0
		elif command -v "$GODOT_BIN" >/dev/null 2>&1; then
			command -v "$GODOT_BIN"
			return 0
		fi
	fi

	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi

	local candidate
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
		if [[ -x "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	echo "Error: Godot executable not found. Put 'godot' in PATH, move Godot.app to /Applications, or set GODOT_BIN=/path/to/Godot." >&2
	return 1
}

GODOT="$(resolve_godot_bin)"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tests/run_tests.gd
