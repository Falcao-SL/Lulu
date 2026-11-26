enum WebChatPage {
    static func html(appearance: LuluAppearance) -> String {
        template.replacingOccurrences(of: "__LULU_APPEARANCE__", with: appearance.rawValue)
    }

    private static let template = #"""
    <!doctype html>
    <html lang="en" data-appearance="__LULU_APPEARANCE__">
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light dark">
    <title>Lulu Chat</title>
    <script>
      const appearanceRoot = document.documentElement;
      const systemDark = matchMedia('(prefers-color-scheme: dark)');
      function applyAppearance(mode = appearanceRoot.dataset.appearance) {
        appearanceRoot.dataset.appearance = mode;
        appearanceRoot.dataset.scheme = mode === 'system' ? (systemDark.matches ? 'dark' : 'light') : mode;
      }
      systemDark.addEventListener('change', () => applyAppearance());
      applyAppearance();
    </script>
    <style>
      :root {
        --page: #f6f5ef; --panel: #fffef9; --ink: #172720; --muted: #4f665a;
        --line: #d1dbd0; --accent: #1d6550; --button-text: #fff; --sent: #e0efe6;
        --shadow: #24433618; --glow: rgba(179, 232, 204, .28); --glow-mid: rgba(179, 232, 204, .10);
        font: 16px/1.55 system-ui, sans-serif; color-scheme: light;
      }
      :root[data-scheme='dark'] {
        --page: #111b19; --panel: #1a2723; --ink: #edf6ef; --muted: #adc4b7;
        --line: #354b42; --accent: #9be6c4; --button-text: #102b20; --sent: #243b33;
        --shadow: #080f0c3d; --glow: rgba(45, 110, 86, .16); --glow-mid: rgba(45, 110, 86, .06);
        color-scheme: dark;
      }
      *, *::before, *::after { box-sizing: border-box; }
      body { margin: 0; height: 100dvh; display: grid; grid-template-rows: auto minmax(0, 1fr); overflow: hidden;
        color: var(--ink); background: var(--page); }
      header { border-bottom: 1px solid var(--line); }
      .bar { min-height: 64px; padding-inline: 16px; display: flex; align-items: center; gap: 12px; }
      .brand { min-width: 0; display: flex; align-items: center; gap: 10px; }
      .icon { width: 1.15em; height: 1.15em; flex: none; fill: none; stroke: currentColor;
        stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
      .cat-mark { display: block; width: 32px; height: 32px; flex: none; fill: var(--accent); }
      h1 { margin: 0; font-size: 1.05rem; line-height: 1.2; letter-spacing: -.025em; }
      #model, #notice, .author { color: var(--muted); font-size: .82rem; margin: 0; }
      #model { overflow-wrap: anywhere; }
      #notice { margin-top: 7px; overflow-wrap: anywhere; }
      .workspace { display: grid; grid-template-columns: minmax(0, 1fr); min-height: 0; position: relative; overflow: hidden; }
      .workspace.sidebar-open { grid-template-columns: 244px minmax(0, 1fr); }
      .sidebar { min-height: 0; min-width: 0; display: grid; grid-template-rows: auto minmax(0, 1fr) auto;
        gap: 12px; padding: 14px 12px; background: var(--panel); border-inline-end: 1px solid var(--line); }
      .sidebar h2 { margin: 0; font-size: .95rem; }
      .sidebar-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
      .chat-list { min-height: 0; overflow: auto; display: flex; flex-direction: column; gap: 4px; }
      .chat-list button { display: block; width: 100%; min-width: 0; overflow: hidden;
        text-overflow: ellipsis; border-color: transparent; text-align: start; flex: none; }
      .chat-list button:hover, .chat-list button[aria-current='true'] { background: var(--sent); }
      .chat-list button[aria-current='true'] { border-inline-start: 3px solid var(--accent); }
      .chat-list p, .history-status { margin: 0; color: var(--muted); font-size: .8rem; overflow-wrap: anywhere; }
      .history-actions { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
      .history-actions button { padding: 5px 7px; font-size: .78rem; }
      @media (max-width: 650px) {
        .workspace.sidebar-open { grid-template-columns: minmax(0, 1fr); }
        .sidebar { position: absolute; z-index: 3; inset: 0 auto 0 0; width: min(85vw, 280px);
          box-shadow: 8px 0 28px var(--shadow); }
      }
      .chat { width: min(100% - 32px, 760px); min-width: 0; min-height: 0; margin-inline: auto;
        display: grid; grid-template-columns: minmax(0, 1fr); grid-template-rows: minmax(0, 1fr) auto; }
      .chat.is-empty { position: relative; grid-template-rows: auto; align-content: center; padding-block: 24px clamp(36px, 12dvh, 120px); }
      .chat.is-empty::before { content: ""; position: absolute; left: 50%; top: 44%;
        width: min(1080px, 140vw); height: min(520px, 72dvh);
        transform: translate(-50%, -50%); pointer-events: none;
        background: radial-gradient(closest-side, var(--glow) 0%, var(--glow-mid) 46%, transparent 100%); }
      .chat.is-empty > * { position: relative; z-index: 1; }
      .welcome-icon { display: grid; place-items: center; width: 64px; height: 64px; margin: 0 auto 17px;
        border-radius: 18px; background: linear-gradient(140deg, #b3e8cc, #e8faf5);
        border: 1px solid rgba(20, 66, 54, .09);
        box-shadow: 0 0 0 6px var(--sent); transform: rotate(-8deg); }
      .welcome-icon .cat-mark { width: 46px; height: 46px; }
      #empty h2 { margin: 0 0 22px; text-align: center; font-size: clamp(1.6rem, 4.4vw, 2.6rem);
        line-height: 1.15; letter-spacing: -.04em; font-weight: 650; }
      #thread { min-width: 0; min-height: 0; padding: 24px 4px 10px;
        overflow-y: auto; overscroll-behavior: contain; scrollbar-gutter: stable; }
      .composer-area { min-width: 0; padding-block: 12px max(16px, env(safe-area-inset-bottom)); }
      .is-empty .composer-area { padding: 0; }
      .is-empty #notice { text-align: center; }
      article { min-width: 0; padding: 15px 17px; margin-bottom: 14px; border-radius: 16px;
        background: var(--panel); border: 1px solid var(--line); }
      article.user { width: fit-content; max-width: 86%; background: var(--sent); margin-inline-start: auto;
        border-color: transparent; }
      article.assistant { background: transparent; border: 0; padding-inline: 8px; }
      .author { display: flex; align-items: center; gap: 6px; font-weight: 650; margin-bottom: 5px; }
      .author .cat-mark { width: 18px; height: 18px; }
      .text { white-space: pre-wrap; overflow-wrap: anywhere; }
      .text.markdown { white-space: normal; }
      .markdown > :first-child { margin-top: 0; }
      .markdown > :last-child { margin-bottom: 0; }
      .markdown :is(h2, h3, h4, h5, h6) { line-height: 1.3; margin-block: 1em .45em; }
      .markdown :is(p, ul, ol, pre, blockquote) { margin-block: .6em; }
      .markdown pre, .markdown > div { overflow-x: auto; }
      .code-block { margin-block: .7em; background: var(--page); border: 1px solid var(--line);
        border-radius: 8px; }
      .code-toolbar { display: flex; align-items: center; gap: 12px; padding: 5px 8px;
        border-bottom: 1px solid var(--line); color: var(--muted); font-size: .8rem; }
      .code-toolbar .copy { margin-inline-start: auto; }
      .markdown .code-block pre { margin: 0; padding: 12px; white-space: pre; }
      .markdown code { padding: .1em .25em; background: var(--page); border-radius: 4px;
        font: .9em ui-monospace, monospace; }
      .markdown pre code { padding: 0; white-space: inherit; overflow-wrap: normal; }
      .markdown blockquote { padding-inline-start: 12px; border-inline-start: 3px solid var(--line); color: var(--muted); }
      .markdown hr { border: 0; border-block-start: 1px solid var(--line); margin-block: 1em; }
      .markdown table { border-collapse: collapse; }
      .markdown :is(th, td) { padding: 4px 10px; border: 1px solid var(--line); text-align: start; }
      .markdown a { color: var(--accent); }
      form { padding: 9px; background: var(--panel);
        border: 1px solid var(--line); border-radius: 18px; box-shadow: 0 6px 20px var(--shadow); }
      .composer-line { display: flex; align-items: flex-end; gap: 6px; }
      .attach { width: 34px; height: 40px; padding: 0; flex: none; color: var(--muted); border-color: transparent; }
      .attach:hover { background: var(--sent); color: var(--accent); }
      .attachments { display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 5px; }
      .attachment { min-width: 0; display: inline-flex; align-items: center; gap: 6px;
        max-width: 100%; padding: 3px 8px; color: var(--muted); border: 1px solid var(--line);
        border-radius: 8px; font-size: .8rem; overflow-wrap: anywhere; }
      .attachment button { padding: 2px 6px; border: 0; }
      form:focus-within { border-color: var(--accent); }
      .is-empty form { padding: 12px; border-radius: 22px; }
      textarea { display: block; flex: 1; min-width: 0; min-height: 40px; max-height: min(25dvh, 12rem);
        padding: 8px 7px; resize: none; field-sizing: content; border: 0; color: inherit;
        background: transparent; font: inherit; }
      .is-empty textarea { min-height: 52px; }
      textarea::placeholder { color: var(--muted); }
      button { display: inline-flex; align-items: center; justify-content: center; gap: 6px;
        padding: 7px 12px; color: inherit; background: transparent; border: 1px solid var(--line);
        border-radius: 9px; font: 600 .84rem/1.5 system-ui, sans-serif; white-space: nowrap; cursor: pointer; }
      [hidden] { display: none !important; }
      button.copy { padding: 4px 8px; color: var(--muted); font-size: .8rem; }
      button.copy:hover { color: var(--ink); }
      .response-actions { display: flex; margin-top: 10px; }
      .visually-hidden { position: absolute; width: 1px; height: 1px; overflow: hidden;
        clip-path: inset(50%); white-space: nowrap; }
      #send, #stop { width: 40px; height: 40px; padding: 0; flex: none; border-radius: 13px;
        color: var(--button-text); background: var(--accent); border-color: transparent; }
      #send .icon, #stop .icon { width: 20px; height: 20px; }
      :focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
      textarea:focus-visible { outline: none; }
      button:disabled { opacity: .55; cursor: default; }
    </style>
    <body>
      <svg width="0" height="0" class="visually-hidden" aria-hidden="true">
        \#(WebChatBrand.symbol)
        <symbol id="icon-new" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></symbol>
        <symbol id="icon-send" viewBox="0 0 24 24"><path d="M12 19V5m-6 6 6-6 6 6"/></symbol>
        <symbol id="icon-stop" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor" stroke="none"/></symbol>
        <symbol id="icon-copy" viewBox="0 0 24 24"><rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 4H6a2 2 0 0 0-2 2v10"/></symbol>
        <symbol id="icon-check" viewBox="0 0 24 24"><path d="m5 12 4 4L19 6"/></symbol>
        <symbol id="icon-history" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M9 4v16"/></symbol>
        <symbol id="icon-image" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8" cy="8" r="1.5"/><path d="m21 16-5-5L6 21"/></symbol>
        <symbol id="icon-audio" viewBox="0 0 24 24"><path d="M4 10v4m4-7v10m4-14v18m4-14v10m4-7v4"/></symbol>
      </svg>
      <template id="copy-control"><button type="button" class="copy"><svg class="icon" aria-hidden="true"><use href="#icon-copy"/></svg><span></span></button></template>
      <header><div class="bar">
        <button id="toggle-history" type="button" aria-label="Chat history" aria-controls="sidebar" aria-expanded="false" title="Chat history"><svg class="icon" aria-hidden="true"><use href="#icon-history"/></svg></button>
        <div class="brand">
          <svg class="cat-mark" aria-hidden="true"><use href="#icon-cat"/></svg>
          <div><h1>Lulu Chat</h1><p id="model" aria-live="polite"></p></div>
        </div>
      </div></header>
      <div class="workspace" id="workspace">
      <aside class="sidebar" id="sidebar" aria-label="Chat history" hidden>
        <div class="sidebar-head"><h2>Chats</h2><button id="reset" type="button"><svg class="icon" aria-hidden="true"><use href="#icon-new"/></svg>New chat</button></div>
        <nav id="chat-list" class="chat-list" aria-label="Saved conversations"></nav>
        <div>
          <p id="history-status" class="history-status" role="status"></p>
          <div class="history-actions">
            <button id="rename-chat" type="button" disabled>Rename</button>
            <button id="export-chat" type="button" disabled>Export .md</button>
            <button id="delete-chat" type="button" disabled>Delete</button>
            <button id="retry-save" type="button" hidden>Retry save</button>
          </div>
        </div>
      </aside>
      <main class="chat is-empty" id="chat">
        <div id="thread" tabindex="0" role="log" aria-label="Conversation" hidden></div>
        <span id="copy-status" role="status" class="visually-hidden"></span>
        <div class="composer-area">
          <div id="empty">
            <span class="welcome-icon" aria-hidden="true"><svg class="cat-mark"><use href="#icon-cat-emblem"/></svg></span>
            <h2>What can I help you with?</h2>
          </div>
          <form id="composer">
            <div id="draft-files" class="attachments" aria-label="Attachments" hidden></div>
            <input type="file" id="pick-image" accept=".jpg,.jpeg,.png" hidden>
            <input type="file" id="pick-audio" accept=".wav,.mp3,.flac" hidden>
            <div class="composer-line">
              <button id="add-image" class="attach" type="button" aria-label="Attach image" title="Attach image" hidden><svg class="icon" aria-hidden="true"><use href="#icon-image"/></svg></button>
              <button id="add-audio" class="attach" type="button" aria-label="Attach audio" title="Attach audio" hidden><svg class="icon" aria-hidden="true"><use href="#icon-audio"/></svg></button>
              <textarea id="input" rows="1" placeholder="Message Lulu" aria-label="Message"></textarea>
              <button id="send" type="submit" aria-label="Send" title="Send" disabled><svg class="icon" aria-hidden="true"><use href="#icon-send"/></svg></button>
              <button id="stop" type="button" aria-label="Stop" title="Stop" hidden><svg class="icon" aria-hidden="true"><use href="#icon-stop"/></svg></button>
            </div>
          </form>
          <p id="notice" role="status"></p>
        </div>
      </main>
      </div>
    <script>
    \#(WebChatMarkdown.script)
      const by = id => document.getElementById(id);
      const form = by('composer'), input = by('input'), thread = by('thread');
      const send = by('send'), stop = by('stop'), reset = by('reset'), notice = by('notice');
      const draftFiles = by('draft-files');
      const mediaFormats = {image: {jpg:'jpeg', jpeg:'jpeg', png:'png'}, audio: {wav:'wav', mp3:'mp3', flac:'flac'}};
      let status = {}, selection, messages = [], active, error = '', timer;
      let draft = [], readingFile = false;
    \#(WebChatHistoryPage.script)

      function fileChip(file, removable) {
        const chip = document.createElement('span');
        chip.className = 'attachment';
        chip.textContent = file.name;
        if (removable) {
          const remove = document.createElement('button');
          remove.type = 'button';
          remove.textContent = '×';
          remove.setAttribute('aria-label', 'Remove ' + file.name);
          remove.addEventListener('click', () => {
            draft = draft.filter(item => item !== file);
            renderDraft();
            input.focus();
          });
          chip.append(remove);
        }
        return chip;
      }

      function renderDraft() {
        draftFiles.replaceChildren(...draft.map(file => fileChip(file, true)));
        draftFiles.hidden = draft.length === 0;
        refresh();
      }

      async function attach(kind, picker) {
        const file = picker.files[0];
        picker.value = '';
        if (!file || !status.ready || !status.inputs?.[kind] || active || readingFile) return;
        const extension = file.name.split('.').at(-1).toLowerCase();
        const format = Object.hasOwn(mediaFormats[kind], extension) ? mediaFormats[kind][extension] : null;
        if (!format || !file.size || file.size > \#(ChatAttachment.maxFileBytes)) {
          error = kind === 'image' ? 'Choose a PNG or JPEG up to 4 MB.' : 'Choose a WAV, MP3 or FLAC up to 4 MB.';
          refresh();
          return;
        }
        const nextDraft = draft.filter(item => item.kind !== kind);
        const files = messages.flatMap(message => message.attachments || []).concat(nextDraft);
        if (files.reduce((bytes, item) => bytes + item.size, file.size) > \#(ChatAttachment.maxConversationBytes)) {
          error = 'Start a new chat to attach more files. This conversation reached 12 MB of attachments.';
          refresh();
          return;
        }
        const model = selection;
        error = '';
        readingFile = true;
        refresh();
        try {
          const encoded = await new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
            reader.readAsDataURL(file);
          });
          if (selection === model && status.inputs?.[kind]) {
            draft = [...draft.filter(item => item.kind !== kind),
              {kind, format, name: file.name, size: file.size, data: encoded.split(',')[1]}];
          }
        } catch {
          error = 'Could not read the attachment.';
        } finally {
          readingFile = false;
          renderDraft();
        }
      }

      function copyButton(label, content) {
        const button = by('copy-control').content.firstElementChild.cloneNode(true);
        const text = button.querySelector('span'), icon = button.querySelector('use');
        text.textContent = label;
        if (label === 'Copy response') button.title = 'Copy the response as Markdown';
        let feedbackTimer;
        button.addEventListener('click', async () => {
          clearTimeout(feedbackTimer);
          let feedback;
          try {
            await navigator.clipboard.writeText(content);
            feedback = 'Copied';
          } catch {
            feedback = 'Copy failed';
          }
          text.textContent = feedback;
          if (feedback === 'Copied') icon.setAttribute('href', '#icon-check');
          by('copy-status').textContent = feedback;
          feedbackTimer = setTimeout(() => {
            text.textContent = label;
            icon.setAttribute('href', '#icon-copy');
          }, 1800);
        });
        return button;
      }

      function refresh() {
        const generating = Boolean(active);
        const label = status.model || 'Local model';
        if (by('model').textContent !== label) by('model').textContent = label;
        const unsupportedFile = attachment => !status.inputs?.[attachment.kind];
        const unsupported = status.ready && (draft.some(unsupportedFile) ||
          messages.some(message => message.attachments?.some(unsupportedFile)));
        const detail = error || (generating ? 'Generating…' : readingFile ? 'Reading attachment…' :
          unsupported ? 'This chat contains attachments the active model cannot read.' : status.message || 'Connecting…');
        if (notice.textContent !== detail) notice.textContent = detail;
        const empty = thread.childElementCount === 0;
        by('chat').classList.toggle('is-empty', empty);
        by('empty').hidden = !empty;
        thread.hidden = empty;
        send.hidden = generating;
        stop.hidden = !generating;
        send.disabled = !status.ready || readingFile || historyBusy || dirty || unsupported || (!input.value.trim() && draft.length === 0);
        for (const kind of ['image', 'audio']) {
          const button = by('add-' + kind);
          button.hidden = !status.inputs?.[kind];
          button.disabled = generating || readingFile || historyBusy;
        }
        syncHistoryControls();
      }

      async function check() {
        clearTimeout(timer);
        if (document.hidden || active) return;
        try {
          const response = await fetch('status', { signal: AbortSignal.timeout(4000) });
          if (!response.ok) throw Error();
          const next = await response.json();
          if (next.appearance !== appearanceRoot.dataset.appearance) applyAppearance(next.appearance);
          if (active) return;
          status = next;
          selection = next.selection;
        } catch {
          status = { message: 'Open Lulu and choose Open chat again to reconnect.' };
        }
        refresh();
        timer = setTimeout(check, status.ready || !status.selection ? 5000 : 1200);
      }

      function bubble(role, content, files = [], parent = thread) {
        const row = document.createElement('article');
        row.className = role;
        const author = document.createElement('div');
        author.className = 'author';
        author.textContent = role === 'user' ? 'You' : 'Lulu';
        if (role === 'assistant') author.prepend(document.querySelector('.brand .cat-mark').cloneNode(true));
        const text = document.createElement('div');
        text.className = 'text';
        text.textContent = content;
        row.append(author);
        if (files.length) {
          const attachments = document.createElement('div');
          attachments.className = 'attachments';
          attachments.append(...files.map(file => fileChip(file, false)));
          row.append(attachments);
        }
        row.append(text);
        parent.append(row);
        return text;
      }

      function formatAnswer(element, content) {
        element.classList.add('markdown');
        element.replaceChildren(markdown(content));
        const actions = document.createElement('div');
        actions.className = 'response-actions';
        actions.append(copyButton('Copy response', content));
        element.after(actions);
      }

      function nearLatest() {
        return thread.scrollHeight - thread.scrollTop - thread.clientHeight < 120;
      }

      function scrollToLatest() { thread.scrollTop = thread.scrollHeight; }

      form.addEventListener('submit', async event => {
        event.preventDefault();
        const prompt = input.value.trim();
        if (send.disabled || active) return;
        clearTimeout(timer);
        const request = new AbortController();
        active = request;
        error = '';
        input.value = '';
        const user = { role: 'user', content: prompt, attachments: draft };
        draft = [];
        renderDraft();
        const answer = { role: 'assistant', content: '' };
        const userText = bubble(user.role, user.content, user.attachments);
        const answerText = bubble(answer.role, '');
        messages.push(user);
        refresh();
        scrollToLatest();
        const liveText = document.createTextNode('');
        answerText.append(liveText);
        let buffer = '', frame = 0;
        function paint() {
          frame = 0;
          const follow = nearLatest();
          liveText.appendData(buffer);
          buffer = '';
          if (follow) scrollToLatest();
        }
        try {
          const response = await fetch('message', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selection, messages }), signal: request.signal
          });
          if (!response.ok) throw Error(await response.text());
          const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
          let pending = '', finished = false;
          for (;;) {
            const { value, done } = await reader.read();
            if (done) break;
            pending += value;
            const lines = pending.split('\n');
            pending = lines.pop();
            for (const line of lines) {
              const event = JSON.parse(line);
              if (event.error) throw Error(event.error);
              if (event.done) finished = true;
              if (!event.text) continue;
              answer.content += event.text;
              buffer += event.text;
              if (!frame) frame = requestAnimationFrame(paint);
            }
          }
          if (!finished) throw Error('The connection closed before the model finished.');
        } catch (cause) {
          if (!request.signal.aborted) error = cause.message || 'The local chat could not connect.';
          request.abort();
        } finally {
          cancelAnimationFrame(frame);
          if (answer.content) {
            const scroll = nearLatest();
            messages.push(answer);
            formatAnswer(answerText, answer.content);
            if (scroll) scrollToLatest();
            conversation.model = status.model || '';
          } else {
            messages.pop();
            answerText.parentElement.remove();
            userText.parentElement.remove();
            if (!input.value) input.value = prompt;
            draft = user.attachments;
            renderDraft();
          }
          active = undefined;
          if (answer.content) await saveConversation();
          refresh();
          if (!error) check();
          else timer = setTimeout(check, 1200);
        }
      });

      input.addEventListener('input', refresh);
      input.addEventListener('keydown', event => {
        if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
          event.preventDefault();
          if (!send.disabled && !active) form.requestSubmit();
        }
      });
      stop.addEventListener('click', () => active?.abort());
      for (const kind of ['image', 'audio']) {
        const picker = by('pick-' + kind);
        by('add-' + kind).addEventListener('click', () => picker.click());
        picker.addEventListener('change', () => attach(kind, picker));
      }
      reset.addEventListener('click', newChat);
      document.addEventListener('visibilitychange', check);
      initializeHistory();
      check();
    </script>
    </body>
    </html>
    """#
}
