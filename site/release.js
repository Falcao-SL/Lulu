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
    const info = document.getElementById("release-info");
    if (!info || typeof release.tag !== "string") return;
    const tail = document.documentElement.lang.startsWith("pt")
      ? "macOS 14 ou mais recente · Apple Silicon e Intel"
      : "macOS 14 or later · Apple Silicon and Intel";
    info.textContent = `${release.tag} · ${tail}`;
  }

  fetch("release.json", { cache: "no-cache" })
    .then((response) => (response.ok ? response.json() : null))
    .then((release) => { if (release) apply(release); })
    .catch(() => {});
})();
