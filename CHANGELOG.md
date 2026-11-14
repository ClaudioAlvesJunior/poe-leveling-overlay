# Histórico de versões

## [v0.1.1](https://github.com/ClaudioAlvesJunior/poe-leveling-overlay/releases/tag/v0.1.1) — 14/11/2026

O guia de campanha ganha uma sobreposição permanente com a rota e as gemas do seu PoB.

### Novidades

- O guia aparece automaticamente sobre o jogo, com zona atual, objetivos, próxima área e gemas do PoB.
- O painel mostra quais gemas pegar ou comprar na etapa, com missão, NPC e preço de referência quando disponível. As habilidades aparecem agrupadas com seus suportes.
- Em **Preferências → Conferir passivas**, compare um XML atualizado do personagem com o plano e avance para a próxima árvore quando a etapa estiver concluída.

### Mudanças

- Use **Avançar** após concluir um objetivo na mesma zona ou **Seguir zona** para retomar a rota após um desvio.
- A preferência de mostrar ou ocultar o guia é lembrada. **Iniciar leveling** e **F10** controlam o acesso ao cronômetro.

### Correções

- O PoE 1 usa o `Client.txt` para detectar a zona e o ato, inclusive ao abrir o overlay com a campanha em andamento.
- Ao chegar ao destino esperado, o guia mostra a etapa seguinte. Uma visita a uma cidade fora da rota atual preserva o progresso.

### Remoções

- Nenhum recurso foi removido.

Use o PoE 1 em janela sem bordas. A conferência de passivas usa um XML exportado pelo Path of Building.

## [v0.1.0](https://github.com/ClaudioAlvesJunior/poe-leveling-overlay/releases/tag/v0.1.0) — 13/11/2026

Primeira versão distribuída pela página pública do NerdMítico Jr.

### Novidades

- Download em ZIP, Wiki em português e página de apoio.
- Painel com a identidade NerdMítico Jr. e infográfico de atalhos em **Ctrl+L**.
- Guia por ato com importação de PoB, perfis, prioridades de itens, sobreposição da árvore e recordes por campanha.

### Mudanças

- A documentação de desenvolvimento ganhou uma página própria. A página inicial agora orienta a instalação e o uso durante a campanha.
- As notas e os downloads passam a ser publicados nas versões deste repositório.

### Correções

- A sobreposição manual da árvore em **F8** funciona sem configurar a detecção de imagem.
- O processo auxiliar carrega mesmo quando o desenho de joias está disponível apenas no processo principal.

### Remoções

- Links e consultas ao projeto original nos menus e no funcionamento do overlay. A atribuição do código reaproveitado está nos créditos.
- Atualizações de tabelas externas pelo projeto original. As árvores disponíveis são as distribuídas com a versão instalada.
