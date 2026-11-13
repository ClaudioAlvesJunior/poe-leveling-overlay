# NerdMítico Jr. | PoE Leveling Overlay

Guia de campanha para Path of Exile 1 no Windows. Usa AutoHotkey 1.1 de 64 bits. 

![Infográfico de atalhos do NerdMítico Jr.](img/GUI/nerdmitico-atalhos.png)

## Começar

1. Abra o PoE 1 em modo janela sem bordas.
2. Execute `Exile UI.ahk` na pasta do overlay. Se o Windows associar o arquivo ao AutoHotkey v2, abra com o `AutoHotkeyU64.exe` da versão 1.1.
3. Pressione **F5** para abrir Campanha ou clique duas vezes no ícone do mago na bandeja do Windows.
4. Clique em **Importar PoB**. Cole um link ou código, ou selecione **Escolher XML**.
5. Use **Preferências** para trocar de perfil, ajustar a rota ou ativar o modo Segundo personagem.

## Desenvolver no VS Code

Abra a pasta do repositório com **Arquivo → Abrir Pasta**. Com o PoE 1 aberto, use **Ctrl+Shift+B** para executar a tarefa **PoE Overlay: executar**. Se o AutoHotkey estiver instalado em outra pasta, defina a variável de ambiente `POE_OVERLAY_AHK` com o caminho completo do `AutoHotkeyU64.exe`.

- `Exile UI.ahk` inicia o aplicativo.
- `modules/build-guide.ahk` contém a interface NerdMítico Jr., a importação do PoB e o cronômetro.
- `data/` e `img/` contêm as tabelas e os recursos usados pelo overlay.

O Git ignora os arquivos de perfil em `ini/`, os PoBs importados, as prioridades e o histórico de runs.
## Atalhos

| Atalho | Ação |
| --- | --- |
| F5 | Abrir Campanha |
| F6 | Abrir Gemas e links |
| F7 | Abrir Equipamento. Frascos e Joias ficam na barra lateral |
| Segurar F8 | Mostrar o esquema sobre a árvore de passivas aberta no jogo |
| Q / E | Trocar de árvore enquanto o esquema está aberto |
| Segurar F9 | Mostrar as referências da zona. Use [ e ] para alternar entre imagens |
| F10 | Iniciar, pausar ou retomar o cronômetro |
| Ctrl+F10 | Salvar a run atual |
| F11 | Abrir Tempos e recordes |
| Ctrl+L | Abrir ou fechar o infográfico de atalhos |

## Campanha, árvore e equipamento

- **Campanha** acompanha as zonas registradas pelo cliente. Use **Anterior**, **Próxima** ou **Seguir zona** para ajustar a etapa. Os nomes de quests, gemas e zonas seguem os dados do jogo e do PoB.
- **Segundo personagem** omite desvios exclusivos de início de liga. Em **Preferências**, ajuste as quests de gemas e as etapas opcionais para esse personagem.
- **Gemas e links** mostra as mudanças entre etapas, recompensas e compras. Os preços conhecidos vêm de `build-guide/precos.ini`. Você pode complementar a tabela.
- **Equipamento, Frascos e Joias** mostram os mods do PoB. Em **Editar prioridades**, escreva um mod por linha. O primeiro é o mais importante.
- **Árvore** funciona ao segurar F8. Abra a árvore no jogo e afaste o zoom ao máximo. Segure F8 e arraste com o botão direito para alinhar. Verde indica novas passivas, vermelho indica pontos a remover e o dourado marca joias.
- **Layout da zona** usa imagens de referência. Para incluir uma imagem própria, salve `build-guide/layouts/<id-da-zona>.png`, `.jpg` ou `.bmp`.
- **Recordes** consideram runs completas iniciadas em Twilight Strand. A entrada no epílogo salva a run automaticamente.

As builds, prioridades e runs ficam em `build-guide`. As preferências e o progresso da campanha ficam em `ini`. Para atualizar a instalação por ZIP, feche o overlay e extraia os arquivos sobre a pasta atual.

Interface e identidade NerdMítico Jr. O motor de campanha, os dados e o desenho das passivas reaproveitam componentes do [Exile UI](https://github.com/Lailloken/Exile-UI), por Lailloken, sob licença MIT. Consulte [Créditos e licenças](CREDITOS.md).
