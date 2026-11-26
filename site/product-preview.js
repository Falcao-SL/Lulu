(() => {
  const source = document.getElementById('preview-source');
  const image = document.getElementById('preview-image');
  const buttons = document.querySelectorAll('[data-screen]');
  if (!source || !image) return;
  const descriptions = {
    overview: ['Overview screen in Lulu', 'Tela Visão geral do Lulu'],
    engines: ['Engines screen in Lulu', 'Tela de motores do Lulu'],
    models: ['Models screen in Lulu', 'Tela de modelos do Lulu'],
    server: ['Server screen in Lulu', 'Tela do servidor do Lulu']
  };
  const language = document.documentElement.lang.startsWith('pt') ? 1 : 0;
  let screen = 'overview';

  function update() {
    const dark = document.documentElement.dataset.appearance === 'dark';
    source.srcset = `screens/${screen}${dark ? '-dark' : ''}.webp`;
    image.src = `screens/${screen}.png`;
    image.alt = descriptions[screen][language];
    buttons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.screen === screen)));
    document.querySelectorAll('[data-themed-screen]').forEach((item) => {
      item.srcset = `screens/${item.dataset.themedScreen}${dark ? '-dark' : ''}.webp`;
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
