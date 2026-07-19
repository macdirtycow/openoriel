# Oriel marketing site

Static landing page for [openoriel.com](https://openoriel.com), hosted on the **Qadbak VPS** (nginx → domain `public_html`), usually behind Cloudflare orange-cloud.

## Deploy (Qadbak)

### A — rsync from Mac (same pattern as inveil / mareades)

```bash
# Default: root@158.220.85.245:/home/openoriel/public_html
bash Scripts/deploy-site-qadbak.sh
```

If the unix user / webroot differs:

```bash
ORIEL_SITE_HOST=root@158.220.85.245 \
ORIEL_SITE_ROOT=/home/YOURUSER/public_html \
  bash Scripts/deploy-site-qadbak.sh
```

Or find the root on the VPS:

```bash
grep -E 'root |server_name' /etc/nginx/sites-enabled/*openoriel*
# or
cat /opt/qadbak/data/domain-config/openoriel.com/website.json
```

### B — Panel zip upload

1. Use `~/Desktop/openoriel-site-upload.zip` (or rebuild: `cd site && zip -r ~/Desktop/openoriel-site-upload.zip . -x '*.DS_Store' -x 'README.md'`)
2. Qadbak → **openoriel.com** → **Files** → `public_html`
3. Enable **Overwrite**, upload, extract **in** `public_html` (not a subfolder)

Expected layout:

```
public_html/
  index.html
  assets/
    site.css
    site.js
    oriel-mark.svg
    oriel-pulse-mark.svg
    favicon.svg
    hero.jpg
```

4. Cloudflare → **Caching → Purge Everything** for `openoriel.com`, then hard refresh.

## Local preview

```bash
cd site
python3 -m http.server 8080
# open http://localhost:8080
```

## Downloads

Buttons hit `https://api.github.com/repos/Ventspew/openoriel/releases/latest` and prefer **PKG**, then DMG, then IPA.
