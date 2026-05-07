#!/usr/bin/env bash
# ============================================================================
# tg-archiv-style installer for Sonarr / Radarr (Docker)
#
# What it does:
#   1. Finds the running Sonarr/Radarr container
#   2. Locates the UI directory inside it (where index.html lives)
#   3. Copies tg-archiv-style.css into that directory
#   4. Patches index.html to include the stylesheet (idempotent)
#
# Usage:
#   ./install.sh sonarr            # patches container named "sonarr"
#   ./install.sh sonarr radarr     # patches both
#   ./install.sh sonarr --fonts    # uses the with-fonts variant
#   ./install.sh sonarr --uninstall  # removes the patch
#
# Caveat: A Sonarr/Radarr update or container recreate wipes the patch.
# Re-run this script after updates, or use the docker-compose persistent
# variant (see compose-snippet.yml) for auto-reapply on every container start.
# ============================================================================

set -euo pipefail

CSS_FILE="tg-archiv-style.css"
UNINSTALL=0
CONTAINERS=()

# Parse args
for arg in "$@"; do
    case "$arg" in
        --fonts)
            CSS_FILE="tg-archiv-style-with-fonts.css"
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --help|-h)
            sed -n '3,20p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            CONTAINERS+=("$arg")
            ;;
    esac
done

if [ ${#CONTAINERS[@]} -eq 0 ]; then
    echo "Usage: $0 <container-name> [more...] [--fonts] [--uninstall]"
    echo "Example: $0 sonarr radarr"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/$CSS_FILE" ] && [ "$UNINSTALL" -eq 0 ]; then
    echo "ERROR: CSS file not found: $SCRIPT_DIR/$CSS_FILE"
    exit 1
fi

# Marker comment we use to detect/remove our patch
PATCH_MARKER="tg-archiv-theme-injected"

patch_container() {
    local container="$1"

    if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
        echo "[$container] NOT RUNNING — skipping."
        return 1
    fi

    # Find the UI directory containing index.html.
    # Common locations across images:
    #   linuxserver/sonarr  → /app/sonarr/bin/UI/index.html
    #                       → /app/sonarr/UI/index.html  (older)
    #   hotio/sonarr        → /app/bin/UI/index.html
    #   official tarball    → /opt/Sonarr/UI/index.html
    # We try known paths, then fall back to find.
    local ui_dir
    ui_dir=$(docker exec "$container" sh -c '
        for path in \
            /app/sonarr/bin/UI \
            /app/sonarr/UI \
            /app/sonarr/bin/Sonarr/UI \
            /app/bin/UI \
            /app/bin/Sonarr/UI \
            /app/Sonarr/UI \
            /opt/Sonarr/UI \
            /opt/sonarr/UI \
            /app/radarr/bin/UI \
            /app/radarr/UI \
            /app/radarr/bin/Radarr/UI \
            /app/bin/Radarr/UI \
            /app/Radarr/UI \
            /opt/Radarr/UI; do
          if [ -f "$path/index.html" ]; then
            echo "$path"
            exit 0
          fi
        done
        # Fallback: search /app and /opt for any index.html in a UI folder
        find /app /opt -maxdepth 6 -type f -name index.html -path "*UI*" 2>/dev/null | head -1 | xargs -r dirname
    ')

    if [ -z "$ui_dir" ]; then
        echo "[$container] ERROR: could not find UI directory with index.html"
        return 1
    fi
    echo "[$container] UI directory: $ui_dir"

    if [ "$UNINSTALL" -eq 1 ]; then
        # Remove our injected <link> tag and CSS file. We use a precise sed
        # that strips only the link tag, preserving </head> on the same line.
        docker exec "$container" sh -c "
            sed -i 's|<link rel=\"stylesheet\" type=\"text/css\" href=\"[^\"]*\" data-patch=\"$PATCH_MARKER\">||g' '$ui_dir/index.html'
            rm -f '$ui_dir/tg-archiv-style.css' '$ui_dir/tg-archiv-style-with-fonts.css'
        "
        echo "[$container] UNINSTALLED."
        return 0
    fi

    # Copy CSS into the container
    docker cp "$SCRIPT_DIR/$CSS_FILE" "$container:$ui_dir/$CSS_FILE"
    echo "[$container] CSS copied: $ui_dir/$CSS_FILE"

    # Patch index.html (idempotent)
    docker exec "$container" sh -c "
        if grep -q '$PATCH_MARKER' '$ui_dir/index.html'; then
            echo '[$container] index.html already patched — skipping injection.'
        else
            # Insert before </head>
            sed -i 's|</head>|<link rel=\"stylesheet\" type=\"text/css\" href=\"$CSS_FILE\" data-patch=\"$PATCH_MARKER\"></head>|' '$ui_dir/index.html'
            echo '[$container] index.html patched.'
        fi
    "

    echo "[$container] DONE — refresh your browser (hard reload: Ctrl+Shift+R)."
}

for c in "${CONTAINERS[@]}"; do
    patch_container "$c" || true
    echo ""
done
