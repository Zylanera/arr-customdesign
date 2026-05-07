#!/usr/bin/with-contenv bash
# ============================================================================
# tg-archiv-style auto-injector for linuxserver.io Sonarr/Radarr containers
#
# Place this file at: /your/sonarr/config/custom-cont-init.d/99-tg-theme.sh
# (chmod +x) — and make sure DOCKER_MODS or custom-init is enabled.
#
# It runs every container start, finds the UI directory, copies the CSS
# from /config/tg-archiv-style.css (which you provide) and patches
# index.html idempotently.
# ============================================================================

set -e

PATCH_MARKER="tg-archiv-theme-injected"
CSS_SRC="/config/tg-archiv-style.css"

if [ ! -f "$CSS_SRC" ]; then
    echo "[tg-theme] No CSS at $CSS_SRC — skipping. Place tg-archiv-style.css there."
    exit 0
fi

# Find the UI dir
UI_DIR=""
for path in \
    /app/sonarr/bin/UI \
    /app/sonarr/UI \
    /app/sonarr/bin/Sonarr/UI \
    /app/bin/UI \
    /app/bin/Sonarr/UI \
    /app/Sonarr/UI \
    /app/radarr/bin/UI \
    /app/radarr/UI \
    /app/radarr/bin/Radarr/UI \
    /app/bin/Radarr/UI \
    /app/Radarr/UI; do
    if [ -f "$path/index.html" ]; then
        UI_DIR="$path"
        break
    fi
done

if [ -z "$UI_DIR" ]; then
    UI_DIR=$(find /app -maxdepth 6 -type f -name index.html -path "*UI*" 2>/dev/null | head -1 | xargs -r dirname)
fi

if [ -z "$UI_DIR" ]; then
    echo "[tg-theme] Could not find UI directory — skipping."
    exit 0
fi

echo "[tg-theme] UI directory: $UI_DIR"

# Copy CSS in (overwrite existing, idempotent)
cp "$CSS_SRC" "$UI_DIR/tg-archiv-style.css"

# Patch index.html if not already patched
if grep -q "$PATCH_MARKER" "$UI_DIR/index.html"; then
    echo "[tg-theme] index.html already patched."
else
    sed -i "s|</head>|<link rel=\"stylesheet\" type=\"text/css\" href=\"tg-archiv-style.css\" data-patch=\"$PATCH_MARKER\"></head>|" "$UI_DIR/index.html"
    echo "[tg-theme] index.html patched."
fi
