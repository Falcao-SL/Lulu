(() => {
  const source = document.getElementById('preview-source');
  const image = document.getElementById('preview-image');
  const buttons = document.querySelectorAll('[data-screen]');
  if (!source || !image) return;
  const descriptions = {
    overview: 'Overview screen in Lulu',
    engines: 'Engines screen in Lulu',
    models: 'Models screen in Lulu',
    server: 'Server screen in Lulu'
  };
  let screen = 'overview';

  function update() {
    const dark = document.documentElement.dataset.appearance === 'dark';
    source.srcset = `screens/${screen}${dark ? '-dark' : ''}.webp?v=english`;
    image.src = `screens/${screen}.png?v=english`;
    image.alt = descriptions[screen];
    buttons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.screen === screen)));
    document.querySelectorAll('[data-themed-screen]').forEach((item) => {
      item.srcset = `screens/${item.dataset.themedScreen}${dark ? '-dark' : ''}.webp?v=english`;
    });
  }

  buttons.forEach(button => button.addEventListener('click', () => {
    if (!Object.hasOwn(descriptions, button.dataset.screen)) return;
    screen = button.dataset.screen;
    update();
  }));
  document.addEventListener('lulu:appearance', update);
  update();
})();
