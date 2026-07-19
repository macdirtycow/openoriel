(() => {
  const nav = document.querySelector(".nav");
  const onScroll = () => {
    if (!nav) return;
    nav.classList.toggle("is-scrolled", window.scrollY > 12);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce) {
    document.querySelectorAll(".reveal").forEach((el) => el.classList.add("is-in"));
  } else {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.18, rootMargin: "0px 0px -8% 0px" }
    );
    document.querySelectorAll(".reveal").forEach((el) => io.observe(el));
  }

  // Wire Download buttons to the latest GitHub release assets when available.
  const meta = document.getElementById("release-meta");
  const ipa = document.getElementById("download-ipa");
  const dmg = document.getElementById("download-dmg");
  const releasesURL = "https://api.github.com/repos/Ventspew/openoriel/releases/latest";

  fetch(releasesURL, {
    headers: { Accept: "application/vnd.github+json" },
  })
    .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
    .then((data) => {
      const assets = Array.isArray(data.assets) ? data.assets : [];
      const find = (pred) => assets.find(pred);
      const ipaAsset = find((a) => /\.ipa$/i.test(a.name || ""));
      const dmgAsset = find((a) => /\.dmg$/i.test(a.name || "") && !/\.sha256$/i.test(a.name || ""));
      if (ipa && ipaAsset?.browser_download_url) {
        ipa.href = ipaAsset.browser_download_url;
        ipa.textContent = "Download IPA";
      }
      if (dmg && dmgAsset?.browser_download_url) {
        dmg.href = dmgAsset.browser_download_url;
        dmg.textContent = "Download DMG";
      }
      if (meta && data.tag_name) {
        meta.hidden = false;
        const label = data.name || data.tag_name;
        const bits = [];
        if (ipaAsset) bits.push("IPA");
        if (dmgAsset) bits.push("DMG");
        meta.textContent = bits.length
          ? `Latest: ${label} · ${bits.join(" + ")} ready`
          : `Latest: ${label}`;
      }
    })
    .catch(() => {
      // Keep the /releases/latest fallbacks from the HTML.
    });
})();
