enum WebChatHistoryPage {
    static let script = #"""
    let conversation = blankConversation(), savedChats = [], historyBusy = false, dirty = false;
    const savedDrafts = new Map(), smallScreen = matchMedia('(max-width: 650px)');

    function blankConversation() {
      return {id: crypto.randomUUID(), title: '', model: '', revision: 0};
    }

    async function historyRequest(path, body) {
      const options = body === undefined ? {} : {
        method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body)
      };
      const response = await fetch(path, options);
      if (!response.ok) throw Error(await response.text());
      return response.json();
    }

    function showHistory(open) {
      by('sidebar').hidden = !open;
      by('workspace').classList.toggle('sidebar-open', open);
      by('toggle-history').setAttribute('aria-expanded', String(open));
    }

    function historyNotice(text) {
      by('history-status').textContent = text;
    }

    function syncHistoryControls() {
      const blocked = Boolean(active) || readingFile || historyBusy;
      const saved = conversation.revision > 0;
      reset.disabled = blocked || dirty;
      by('rename-chat').disabled = blocked || dirty || !saved;
      by('delete-chat').disabled = blocked || dirty || !saved;
      by('export-chat').disabled = messages.length === 0 || Boolean(active);
      by('retry-save').hidden = !dirty;
      by('retry-save').disabled = blocked;
    }

    function renderHistory() {
      const list = by('chat-list');
      list.replaceChildren();
      for (const entry of savedChats) {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = entry.title;
        button.title = entry.title;
        button.setAttribute('aria-current', String(entry.id === conversation.id));
        button.addEventListener('click', () => openConversation(entry.id));
        list.append(button);
      }
      if (!savedChats.length) {
        const empty = document.createElement('p');
        empty.textContent = 'Saved chats will appear here.';
        list.append(empty);
      }
      syncHistoryControls();
    }

    function stashDraft() {
      if (conversation.revision && (input.value || draft.length)) {
        savedDrafts.set(conversation.id, {text: input.value, files: draft});
      } else savedDrafts.delete(conversation.id);
    }

    function setConversation(entry, transcript) {
      conversation = entry;
      messages = transcript;
      const pending = savedDrafts.get(entry.id);
      draft = pending?.files || [];
      input.value = pending?.text || '';
      error = '';
      const fragment = document.createDocumentFragment();
      for (const message of messages) {
        const text = bubble(message.role, message.content, message.attachments || [], fragment);
        if (message.role === 'assistant') formatAnswer(text, message.content);
      }
      thread.replaceChildren(fragment);
      history.replaceState(null, '', entry.revision ? '#' + entry.id : '#new');
      renderDraft();
      renderHistory();
      scrollToLatest();
    }

    function newChat() {
      if (active || historyBusy || dirty || readingFile) return;
      stashDraft();
      setConversation(blankConversation(), []);
      historyNotice('');
      if (smallScreen.matches) showHistory(false);
      input.focus();
    }

    async function openConversation(id) {
      if (active || historyBusy || dirty || readingFile || id === conversation.id) return;
      historyBusy = true;
      refresh();
      try {
        const entry = await historyRequest('history/load', {id});
        stashDraft();
        const {messages: transcript, ...summary} = entry;
        setConversation(summary, transcript);
        historyNotice('');
        if (smallScreen.matches) showHistory(false);
      } catch (cause) {
        historyNotice(cause.message);
        error = cause.message;
      } finally {
        historyBusy = false;
        refresh();
      }
    }

    function titleFromMessages() {
      const first = messages.find(message => message.role === 'user');
      const text = first?.content.trim().replace(/\s+/g, ' ');
      return (text || first?.attachments?.[0]?.name || 'New chat').slice(0, 80);
    }

    async function saveConversation(title = conversation.title) {
      if (historyBusy || !messages.length) return;
      historyBusy = true;
      dirty = true;
      refresh();
      try {
        const entry = await historyRequest('history/save', {
          ...conversation, title: title || titleFromMessages(), messages
        });
        conversation = entry;
        history.replaceState(null, '', '#' + entry.id);
        savedChats = [entry, ...savedChats.filter(chat => chat.id !== entry.id)];
        dirty = false;
        historyNotice('');
        renderHistory();
      } catch (cause) {
        conversation.title = title;
        historyNotice(cause.message);
        error = cause.message;
      } finally {
        historyBusy = false;
        refresh();
      }
    }

    async function deleteConversation() {
      if (historyBusy || dirty || active || !conversation.revision || !confirm('Delete this chat from Lulu?')) return;
      historyBusy = true;
      refresh();
      try {
        await historyRequest('history/delete', {id: conversation.id, revision: conversation.revision});
        savedChats = savedChats.filter(entry => entry.id !== conversation.id);
        savedDrafts.delete(conversation.id);
        setConversation(blankConversation(), []);
        historyNotice('');
      } catch (cause) {
        historyNotice(cause.message);
        error = cause.message;
      } finally {
        historyBusy = false;
        refresh();
      }
    }

    function exportConversation() {
      if (!messages.length || active) return;
      const title = conversation.title || titleFromMessages();
      const markdownText = ['# ' + title.replace(/\s+/g, ' ')];
      if (conversation.model) markdownText.push('Model: ' + conversation.model.replace(/\s+/g, ' '));
      for (const message of messages) {
        const author = message.role === 'user' ? 'You' : 'Lulu';
        markdownText.push('## ' + author, message.content);
        if (message.attachments?.length) {
          const names = message.attachments.map(file => (file.name || file.format).replace(/\s+/g, ' '));
          markdownText.push('Attachments: ' + names.join(', '));
        }
      }
      const download = document.createElement('a');
      const url = URL.createObjectURL(new Blob([markdownText.join('\n\n') + '\n'], {type:'text/markdown;charset=utf-8'}));
      download.href = url;
      download.download = (title.replace(/[^\p{L}\p{N} _-]/gu, '').trim().slice(0, 80) || 'Lulu chat') + '.md';
      document.body.append(download);
      download.click();
      download.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }

    async function initializeHistory() {
      showHistory(!smallScreen.matches);
      smallScreen.addEventListener('change', () => showHistory(!smallScreen.matches));
      by('toggle-history').addEventListener('click', () => showHistory(by('sidebar').hidden));
      by('rename-chat').addEventListener('click', () => {
        const title = prompt('Rename this chat', conversation.title)?.trim();
        if (title && title !== conversation.title) saveConversation(title.slice(0, 100));
      });
      by('export-chat').addEventListener('click', exportConversation);
      by('delete-chat').addEventListener('click', deleteConversation);
      by('retry-save').addEventListener('click', () => { error = ''; saveConversation(); });
      historyBusy = true;
      refresh();
      try {
        savedChats = await historyRequest('history');
      } catch (cause) {
        historyNotice(cause.message);
      } finally {
        historyBusy = false;
        renderHistory();
        refresh();
      }
      const id = location.hash.slice(1);
      if (savedChats.some(entry => entry.id === id)) await openConversation(id);
    }
    """#
}
