(() => {
  const storageKey = 'lulu.siteAppearance';
  const system = matchMedia('(prefers-color-scheme: dark)');
  const root = document.documentElement;
  let choice = 'system';
  try {
    const saved = localStorage.getItem(storageKey);
    if (saved === 'light' || saved === 'dark') choice = saved;
  } catch {}

  function apply() {
    root.dataset.appearance = choice === 'system' ? (system.matches ? 'dark' : 'light') : choice;
  }

  apply();

  document.addEventListener('DOMContentLoaded', () => {
    const control = document.querySelector('[data-appearance-control]');
    if (!control) return;
    const picker = control.querySelector('select');
    const systemOption = picker.querySelector('[value=system]');
    const demo = document.querySelector('#demo video');
    const source = demo.querySelector('source');
    if (!systemOption || !source) return;

    function update() {
      apply();
      const mode = root.dataset.appearance;
      control.dataset.mode = mode;
      picker.value = choice;
      document.querySelectorAll('[data-tray-theme]').forEach((figure) => {
        figure.dataset.active = String(figure.dataset.trayTheme === mode);
      });

      const clip = mode === 'dark' ? 'tour-dark' : 'tour';
      const url = `screens/${clip}.mp4?v=english`;
      if (source.getAttribute('src') !== url) {
        demo.poster = `screens/${clip}-poster.jpg?v=english`;
        source.src = url;
        demo.load();
      }
      document.dispatchEvent(new Event('lulu:appearance'));
    }

    picker.addEventListener('change', () => {
      choice = picker.value;
      try { localStorage.setItem(storageKey, choice); } catch {}
      update();
    });
    system.addEventListener('change', update);
    update();
    control.hidden = false;
  });
})();
