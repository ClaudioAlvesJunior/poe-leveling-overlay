# Desenvolvimento no VS Code

Abra a pasta do repositório em **Arquivo → Abrir pasta**. Com o PoE 1 aberto, use **Ctrl+Shift+B** para executar **PoE Overlay: executar**. Se o AutoHotkey estiver em outro local, defina `POE_OVERLAY_AHK` com o caminho do `AutoHotkeyU64.exe`.

- `Exile UI.ahk` inicia o aplicativo.
- `modules/build-guide.ahk` contém o painel, a importação do PoB e o cronômetro.
- `data/` e `img/` contêm as tabelas e os recursos distribuídos.
- [AGENTS.md](../AGENTS.md) e [`.agents/skills/`](../.agents/skills/) orientam tarefas futuras no Codex.

Para validar a importação fora do jogo, execute `Exile UI.ahk --test-build-guide <xml-de-teste> <relatorio.txt>` com o AutoHotkey 1.1 de 64 bits. O teste embutido usa asserções de uma build de referência com estágios e Essence Drain no primeiro conjunto. Use um XML compatível para esse teste e mantenha o arquivo fora do Git.

[Fluxo de publicação](PUBLICACAO.md)
