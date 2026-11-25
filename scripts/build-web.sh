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

mkdir -p web
touch web/.gdignore
rm -f web/index.wasm web/index.wasm.bin web/*.import
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" web/index.html

if [[ ! -f web/index.wasm ]]; then
	echo "Error: web/index.wasm was not generated. Make sure matching Godot 4.6 Export Templates are installed (Editor -> Manage Export Templates)." >&2
	exit 1
fi

WASM_SIZE=$(python3 -c 'import os; print(os.path.getsize("web/index.wasm"))')
gzip -9 -c web/index.wasm > web/index.wasm.bin
rm -f web/index.wasm

python3 - "$WASM_SIZE" <<'PY'
import sys

wasm_size = sys.argv[1]
html_path = "web/index.html"
with open(html_path, "r", encoding="utf-8") as f:
    html = f.read()

interceptor = f"""<script>
(function () {{
	const origFetch = window.fetch.bind(window);
	window.fetch = async function (input, init) {{
		const url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
		if (url.endsWith('index.wasm')) {{
			const binUrl = url.slice(0, -'index.wasm'.length) + 'index.wasm.bin';
			const resp = await origFetch(binUrl, init);
			if (!resp.ok || !resp.body) {{
				return resp;
			}}
			const stream = resp.body.pipeThrough(new DecompressionStream('gzip'));
			return new Response(stream, {{
				status: 200,
				headers: {{
					'Content-Type': 'application/wasm',
					'Content-Length': '{wasm_size}'
				}}
			}});
		}}
		return origFetch(input, init);
	}};
}})();
</script>
		<script src="index.js"></script>"""

if "index.wasm.bin" not in html:
    html = html.replace('<script src="index.js"></script>', interceptor, 1)
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)
PY
