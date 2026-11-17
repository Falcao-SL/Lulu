(() => {
  const allowed = "https://github.com/Falcao-SL/Lulu/releases/download/";

  function setHref(id, url) {
    if (!url || !url.startsWith(allowed)) return;
    const link = document.getElementById(id);
    if (link) link.href = url;
  }

  function apply(release) {
    setHref("download", release.arm64);
    setHref("download-bottom", release.arm64);
    setHref("download-intel", release.intel);
    setHref("download-intel-bottom", release.intel);
    if (typeof release.tag !== "string") return;
    document.querySelectorAll(".js-tag").forEach((node) => {
      node.textContent = release.tag;
    });
  }

  function prefersIntel() {
    try {
      const canvas = document.createElement("canvas");
      const gl = canvas.getContext("webgl") || canvas.getContext("experimental-webgl");
      if (!gl) return null;
      const ext = gl.getExtension("WEBGL_debug_renderer_info");
      if (!ext) return null;
      const renderer = String(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) || "");
      if (/Apple M\d/i.test(renderer)) return false;
      if (/Intel/i.test(renderer)) return true;
    } catch (error) {
      return null;
    }
    return null;
  }

  const intel = prefersIntel();
  if (intel !== null) {
    document.querySelectorAll("[data-arch]").forEach((link) => {
      const match = (link.dataset.arch === "intel") === intel;
      link.classList.toggle("primary", match);
      link.classList.toggle("secondary", !match);
      link.style.order = match ? "0" : "1";
    });
  }

  fetch("release.json", { cache: "no-cache" })
    .then((response) => (response.ok ? response.json() : null))
    .then((release) => { if (release) apply(release); })
    .catch(() => {});
})();
