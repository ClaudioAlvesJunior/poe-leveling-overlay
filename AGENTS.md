# Instruções para agentes

- Escreva a documentação, a interface nova e as notas públicas em português do Brasil. Preserve nomes de itens, gemas, quests e identificadores conforme as fontes do jogo.
- Este projeto é o **NerdMítico Jr. | PoE Leveling Overlay**. Use o repositório `ClaudioAlvesJunior/poe-leveling-overlay` em links do aplicativo e downloads. Preserve os avisos legais em `CREDITOS.md` e `LICENSE-EXILE-UI.txt`.
- O ponto de entrada é `Exile UI.ahk`. O painel e seus atalhos ficam em `modules/build-guide.ahk`. O módulo `modules/leveling tracker.ahk` também é incluído no processo auxiliar.
- Preserve compatibilidade com AutoHotkey 1.1 de 64 bits e UTF-8 com BOM nos scripts AHK que contêm caracteres acentuados.
- Deixe perfis, PoBs importados, prioridades, logs e runs no armazenamento local. Confira os arquivos que entrarão no commit e no ZIP.
- Em mudanças no overlay ou no PoB, use [poe-overlay-manutencao](.agents/skills/poe-overlay-manutencao/SKILL.md). Em tarefas de versão, use [poe-overlay-release](.agents/skills/poe-overlay-release/SKILL.md).
- Mantenha o README voltado a jogadores. Documentação para desenvolvimento fica em `docs/DESENVOLVIMENTO.md`.
