---
name: poe-overlay-manutencao
description: Corrigir e validar importação de PoB, campanha, interface e atalhos do NerdMítico Jr. PoE Leveling Overlay. Use em manutenção do aplicativo AutoHotkey deste repositório.
---

# Manutenção do overlay

1. Encontre o fluxo em `modules/build-guide.ahk`. Confira os caminhos compartilhados com `modules/leveling tracker.ahk` antes de mudar a árvore. O processo auxiliar inclui o rastreador e carrega sem o painel.
2. Preserve os dados locais e a execução com AutoHotkey 1.1 de 64 bits. Use um PoB de teste fora do Git. O teste local de importação é descrito em [Desenvolvimento](../../../docs/DESENVOLVIMENTO.md).
3. Se mudar um atalho ou o fluxo do jogador, atualize a Wiki e o infográfico quando ele mostrar a informação. Na entrega, indique o que foi testado dentro e fora do jogo.
