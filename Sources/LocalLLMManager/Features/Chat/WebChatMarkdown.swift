enum WebChatMarkdown {
    static let script = #"""
    function markdown(source) {
      const output = document.createDocumentFragment();
      const lines = source.replace(/\r\n?/g, '\n').split('\n');
      const fence = /^ {0,3}(`{3,}|~{3,})([^\s`~]*)[^\n]*$/;
      const heading = /^ {0,3}(#{1,6})\s+(.+?)(?:\s+#+)?\s*$/;
      const rule = /^ {0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$/;
      const list = /^ {0,3}([-+*]|\d{1,9}[.)])\s+(.+)$/;
      const quote = /^ {0,3}> ?(.*)$/;
      const cells = line => line.trim().replace(/^\||\|$/g, '').split(/(?<!\\)\|/).map(cell => cell.trim());
      const table = i => lines[i]?.includes('|') && lines[i + 1]?.includes('|')
        && cells(lines[i]).length === cells(lines[i + 1]).length
        && cells(lines[i + 1]).every(cell => /^:?-{3,}:?$/.test(cell));
      const startBlock = i => !lines[i].trim() || [fence, heading, rule, list, quote].some(pattern => pattern.test(lines[i])) || table(i);

      function add(parent, tag, value) {
        const element = document.createElement(tag);
        if (value !== undefined) element.textContent = value;
        parent.append(element);
        return element;
      }

      function inline(parent, text, depth = 0) {
        if (depth > 6) { parent.append(text); return; }
        const tokens = /\\([!-/:-@\[-`{-~])|(`+)([^\n]+?)\2(?!`)|\[([^\]\n]+)\]\(([^\s()]+)\)|(\*\*|__|~~|\*|_)(?=\S)(.+?)(?<=\S)\6/g;
        let from = 0;
        for (const token of text.matchAll(tokens)) {
          parent.append(text.slice(from, token.index));
          from = token.index + token[0].length;
          if (token[1]) parent.append(token[1]);
          else if (token[2]) add(parent, 'code', token[3]);
          else if (token[4]) {
            if (!/^https?:\/\//i.test(token[5])) { parent.append(token[0]); continue; }
            const link = add(parent, 'a');
            link.href = token[5];
            link.target = '_blank';
            link.rel = 'noopener noreferrer';
            inline(link, token[4], depth + 1);
          } else {
            const tag = token[6] === '~~' ? 'del' : token[6].length === 2 ? 'strong' : 'em';
            inline(add(parent, tag), token[7], depth + 1);
          }
        }
        parent.append(text.slice(from));
      }

      for (let i = 0; i < lines.length;) {
        const line = lines[i++];
        if (!line.trim()) continue;
        const code = line.match(fence);
        const title = line.match(heading);
        const bullet = line.match(list);
        if (code) {
          const body = [];
          const closing = new RegExp('^ {0,3}' + code[1][0] + '{' + code[1].length + ',}\\s*$');
          while (i < lines.length && !closing.test(lines[i])) body.push(lines[i++]);
          if (i < lines.length) i++;
          const block = add(output, 'div');
          block.className = 'code-block';
          const toolbar = add(block, 'div');
          toolbar.className = 'code-toolbar';
          if (code[2]) add(toolbar, 'span', code[2]);
          const content = body.join('\n');
          toolbar.append(copyButton('Copy code', content));
          add(add(block, 'pre'), 'code', content);
        } else if (title) {
          inline(add(output, 'h' + Math.max(2, title[1].length)), title[2]);
        } else if (rule.test(line)) add(output, 'hr');
        else if (quote.test(line)) {
          const passage = [line.match(quote)[1]];
          while (i < lines.length && quote.test(lines[i])) passage.push(lines[i++].match(quote)[1]);
          inline(add(output, 'blockquote'), passage.join('\n'));
        } else if (bullet) {
          const ordered = /^\d/.test(bullet[1]);
          const items = add(output, ordered ? 'ol' : 'ul');
          if (ordered) items.start = parseInt(bullet[1], 10);
          inline(add(items, 'li'), bullet[2]);
          while (i < lines.length && !rule.test(lines[i])) {
            const next = lines[i].match(list);
            if (!next || /^\d/.test(next[1]) !== ordered) break;
            inline(add(items, 'li'), next[2]);
            i++;
          }
        } else if (table(i - 1)) {
          const columns = cells(line);
          const grid = add(add(output, 'div'), 'table');
          const head = add(add(grid, 'thead'), 'tr');
          for (const column of columns) inline(add(head, 'th'), column);
          const body = add(grid, 'tbody');
          i++;
          while (i < lines.length && lines[i].includes('|') && !fence.test(lines[i])) {
            const row = add(body, 'tr');
            const values = cells(lines[i++]);
            for (let j = 0; j < columns.length; j++) inline(add(row, 'td'), values[j] || '');
          }
        } else {
          const paragraph = [line];
          while (i < lines.length && !startBlock(i)) paragraph.push(lines[i++]);
          inline(add(output, 'p'), paragraph.join('\n'));
        }
      }
      return output;
    }
    """#
}
