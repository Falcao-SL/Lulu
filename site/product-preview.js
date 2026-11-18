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
  buttons.forEach(button => button.addEventListener('click', () => {
    const screen = button.dataset.screen;
    if (!Object.hasOwn(descriptions, screen)) return;
    source.srcset = `screens/${screen}.webp`;
    image.src = `screens/${screen}.png`;
    image.alt = descriptions[screen][language];
    buttons.forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  }));
})();
