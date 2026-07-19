# Oriel marketing site

Static landing page for [openoriel.com](https://openoriel.com) (Cloudflare Pages).

## What it covers

- Classic / Pulse editions
- Smart dual engine on Mac (WebKit + Chromium Compatible / Native Blink via CEF or managed Chromium)
- Password Vault, Mac governors, everyday page tools
- Privacy and tracking controls (Shields + Fire)
- Platforms (iPhone, iPad, Mac)
- Download via latest GitHub Release (unsigned IPA + macOS DMG)

## Layout (one job per section)

1. **Hero** — brand + one CTA
2. **Download** — latest release assets
3. **Editions** — Classic vs Pulse
4. **Pulse** — vermillion signal on obsidian
5. **Features** — everyday + Mac power tools
6. **Engines** — honest Smart / Compatible / Native story
7. **Privacy** — Shields + vault notes
8. **Platforms** — iOS / iPadOS / macOS
9. **Open source** — GitHub
10. **Footer**

## Deploy

Publish the `site/` folder to Cloudflare Pages (or any static host). The download buttons hit:

`https://api.github.com/repos/Ventspew/openoriel/releases/latest`

No build step. Edit HTML/CSS/JS and redeploy.

## Local preview

```bash
cd site
python3 -m http.server 8080
# open http://localhost:8080
```
