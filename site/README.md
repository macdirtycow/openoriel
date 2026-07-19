# openoriel.com

Static marketing site for Oriel.

```bash
cd site
python3 -m http.server 8080
# open http://localhost:8080
```

Deploy the `site/` folder to any static host (Cloudflare Pages, GitHub Pages, Netlify, Vercel). Point `openoriel.com` at it.

The Download section loads the latest IPA/DMG URLs from the GitHub Releases API (`/repos/macdirtycow/openoriel/releases/latest`).
