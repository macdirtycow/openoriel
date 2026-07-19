# Oriel marketing site

Static landing page for [openoriel.com](https://openoriel.com) (Cloudflare Pages).

## What it covers

- Classic / Pulse editions
- Dual engine (WebKit + Chromium Compatible / Native)
- Privacy and tracking controls
- Platforms (iPhone, iPad, Mac)
- Download via latest GitHub Release (unsigned IPA)

## Layout (one job per section)

1. **Hero** — brand + one CTA
2. **Editions** — Classic vs Pulse
3. **Pulse** — vermillion signal on obsidian
4. **Features** — everyday + Mac power tools
5. **Engines** — honest dual-engine story
6. **Privacy** — tracking + vault
7. **Platforms** — iOS / iPadOS / macOS
8. **Download** — latest release + TestFlight note
9. **Footer**

## Deploy

Publish the `site/` folder to Cloudflare Pages (or any static host). The download button hits:

`https://api.github.com/repos/macdirtycow/openoriel/releases/latest`

No build step. Edit HTML/CSS/JS and redeploy.

## Local preview

```bash
cd site
python3 -m http.server 8080
# open http://localhost:8080
```
