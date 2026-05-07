Here’s the English version of your text:

---

# Inside-Container Installer

> **Important:** Sonarr’s built-in theme dropdown (Auto / Light / Dark)
> is hardcoded and cannot be extended. Themes exist as TypeScript objects
> inside the JS bundle, not as external CSS files. What this does instead:
> we sneak an additional stylesheet into the HTML, which gets loaded *on top of*
> the selected Sonarr theme and overrides it.

## Method 1: install.sh — quick, one-time

Patches the running container *right now*. Recreating the container
(e.g. after an image update) could wipe the changes → run the script again afterward if needed.

```bash
chmod +x install.sh
./install.sh sonarr radarr           # patches both
./install.sh sonarr --fonts          # use the with-fonts variant
./install.sh sonarr --uninstall      # remove the patch
```

Requirement: You have shell access to the Docker host and Docker CLI.

The script:

1. Locates the UI directory inside the container (tries common paths,
   falls back to `find /app -name index.html -path "*UI*"`).
2. Copies `tg-archiv-style.css` into the UI directory.
3. Injects a `<link>` tag before `</head>` in `index.html`, using a marker
   attribute to prevent duplicate injections.

Browser tab → hard reload (Ctrl+Shift+R for Mac or Ctrl + F5 for Windows) → done.

## Method 2: custom-cont-init script — for linuxserver images

This approach survives container updates automatically. Works only with
**linuxserver.io** images (e.g. `lscr.io/linuxserver/sonarr` or `...../radarr`) because they provide
the `custom-cont-init.d` mechanism.

### Setup

Per container (Sonarr and Radarr separately):

```bash
# 1. Copy to the Docker host — e.g. into Sonarr's config folder
cp tg-archiv-style.css /your/sonarr/config/

# 2. Place init script in the custom folder
mkdir -p /your/sonarr/config/custom-cont-init.d
cp 99-tg-theme.sh /your/sonarr/config/custom-cont-init.d/
chmod +x /your/sonarr/config/custom-cont-init.d/99-tg-theme.sh

# 3. Container does NOT need DOCKER_MODS=linuxserver/mods:universal-package-install
#    — custom-cont-init.d is built into linuxserver images.
#    However: if your container is configured restrictively (DOCKER_MODS_VERSION 
#    etc.), it may be worth double-checking.

# 4. Restart container
docker restart {containername}
```

Same setup for Radarr under `/your/radarr/config/`.

The script now runs on every container start (including after updates), patches
the UI, and that’s it. If you want to update the theme, just replace
`tg-archiv-style.css` in the config folder and restart the container.

### If your image does not support `custom-cont-init.d`

For non-linuxserver images (e.g. `hotio/sonarr`, `ghcr.io/randomwhatever/...`),
this mechanism is not available. In that case, fall back to Method 1
(run `install.sh` after every update if needed), or use a cron job on the host:

```bash
# crontab -e
@reboot                              /path/to/install.sh sonarr radarr
0 4 * * *  /path/to/install.sh sonarr radarr   # daily safety re-patch
```

## Method 3: Stylus browser extension — if all of this is overkill

Works instantly, but only in the browser with the extension.

---

## Questions / Issues

* **"It worked, but after a Sonarr update it reverted"**
  → Method 2 not set up, or Sonarr/Radarr introduced major frontend changes.
  Try `install.sh` again first, then adjust CSS selectors if needed
  (Browser DevTools → find new class name prefixes → update CSS accordingly).

* **"How do I check if it's patched?"**
  → `docker exec sonarr grep tg-archiv UI/index.html` — should show
  the injected `<link>`. (Adjust path if the UI is located elsewhere.)

* **"My container is `hotio/sonarr`"**
  → The UI path is usually `/app/bin/Sonarr/UI` (case-sensitive).
  `install.sh` detects this automatically. Method 2 won’t work directly;
  use `install.sh` + cron, or Stylus instead.
