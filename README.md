# tg-archiv-style — Inside-Container Installer

Du wolltest die CSS direkt in Sonarr "reinklatschen", ohne Reverse-Proxy davor.
Hier sind zwei Wege dafür — beide injizieren das CSS direkt in Sonarr's
`index.html` im Container, also funktioniert's mit deinem Cloudflare-Tunnel-Setup
ohne Modifikation am Tunnel.

> **Wichtig vorab:** Sonarr's eingebautes Theme-Dropdown (Auto / Light / Dark)
> ist hardcoded und kann nicht erweitert werden. Themes leben als TS-Objekte
> im JS-Bundle, nicht als externe CSS-Files. Was hier passiert: Wir schmuggeln
> ein zusätzliches Stylesheet in die HTML rein, das *zusätzlich* zum gewählten
> Sonarr-Theme geladen wird und es überschreibt. Praktisch das gleiche Ergebnis,
> nur ohne UI-Picker.

## Methode 1: install.sh — schnell, einmalig

Patcht den laufenden Container *jetzt sofort*. Eine Container-Recreate
(z.B. nach Image-Update) wischt's weg → Script danach erneut ausführen.

```bash
chmod +x install.sh
./install.sh sonarr radarr           # patches both
./install.sh sonarr --fonts          # use the with-fonts variant
./install.sh sonarr --uninstall      # remove the patch
```

Voraussetzung: Du hast Shell-Zugriff auf den Docker-Host und Docker-CLI.

Das Script:
1. Findet den UI-Ordner im Container (probiert die üblichen Pfade durch,
   sucht als Fallback per `find /app -name index.html -path "*UI*"`)
2. Kopiert `tg-archiv-style.css` in den UI-Ordner
3. Fügt einen `<link>`-Tag vor `</head>` in `index.html` ein, mit einem
   Marker-Attribut um Doppel-Injects zu vermeiden

Browser-Tab → harter Reload (Strg+Shift+R) → fertig.

## Methode 2: custom-cont-init Script — persistent für linuxserver-Images

Dieser Weg überlebt Container-Updates automatisch. Funktioniert nur mit
**linuxserver.io** Images (lscr.io/linuxserver/sonarr usw.), weil der die
`custom-cont-init.d`-Mechanik bereitstellt.

### Setup

Pro Container (Sonarr und Radarr separat):

```bash
# 1. Auf den Docker-Host kopieren — z.B. nach Sonarr's config-Ordner
cp tg-archiv-style.css /your/sonarr/config/

# 2. Init-Script in den custom-Ordner
mkdir -p /your/sonarr/config/custom-cont-init.d
cp 99-tg-theme.sh /your/sonarr/config/custom-cont-init.d/
chmod +x /your/sonarr/config/custom-cont-init.d/99-tg-theme.sh

# 3. Container muss DOCKER_MODS=linuxserver/mods:universal-package-install
#    NICHT brauchen — custom-cont-init.d ist eingebaut bei linuxserver-Images.
#    Aber: Falls dein Container restriktiv konfiguriert ist (DOCKER_MODS_VERSION 
#    o.ä.), eventuell einmal überprüfen.

# 4. Container neu starten
docker restart sonarr
```

Same Sache für Radarr unter `/your/radarr/config/`.

Das Script läuft jetzt bei jedem Container-Start (auch nach Updates), patcht die
UI, fertig. Wenn du das Theme aktualisieren willst, ersetze einfach die
`tg-archiv-style.css` im config-Ordner und restart den Container.

### Falls dein Image kein `custom-cont-init.d` hat

Bei nicht-linuxserver Images (z.B. `hotio/sonarr`, `ghcr.io/randomwhatever/...`)
gibt's die Mechanik nicht. Dort musst du auf Methode 1 (install.sh nach jedem
Update neu ausführen) zurückfallen, oder einen Cron-Job auf dem Host:

```bash
# crontab -e
@reboot                              /path/to/install.sh sonarr radarr
0 4 * * *  /path/to/install.sh sonarr radarr   # daily safety re-patch
```

## Methode 3: Stylus-Browser-Extension — falls dir das alles zu viel ist

Im README.md im selben Zip beschrieben. Funktioniert sofort, nur im Browser
mit der Extension.

---

## Fragen / Probleme

- **"Hat funktioniert, aber nach Sonarr-Update ist's wieder das alte Design"**
  → Methode 2 nicht eingerichtet, oder Sonarr/Radarr hat größere
  Frontend-Änderung gemacht. Erst install.sh nochmal versuchen, dann ggf.
  Selektoren in der CSS anpassen (Browser DevTools → neuen Klassennamen-Prefix
  finden → in CSS unten ergänzen).

- **"Wie sehe ich ob's gepatcht ist?"**
  → `docker exec sonarr grep tg-archiv UI/index.html` — sollte den
  injizierten `<link>` zeigen. (Pfad ggf. anpassen wenn UI woanders liegt.)

- **"Mein Container ist `hotio/sonarr`"**
  → Der UI-Pfad ist meistens `/app/bin/Sonarr/UI` (Großschreibung beachten).
  install.sh findet das automatisch. Methode 2 geht nicht direkt; nutze
  install.sh + Cron, oder Stylus.
