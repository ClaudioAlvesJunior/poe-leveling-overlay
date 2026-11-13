# Publicação de versões

1. Compare a versão anterior com a branch `main`. Registre **Novidades**, **Mudanças**, **Correções** e **Remoções** no [histórico](../CHANGELOG.md), com data e link para a versão. Inclua limitações que afetem quem instala.
2. Valide a importação e os pontos alterados no aplicativo. Confira os arquivos rastreados e faça o commit com a documentação.
3. Na raiz do repositório, gere o ZIP a partir do commit. Isso exclui o estado local ignorado pelo Git.

   ```powershell
   git archive --format=zip --prefix=PoE-Leveling-Overlay/ --output=NerdMiticoJr-PoE-Leveling-Overlay.zip HEAD
   ```

4. Publique a tag e o ZIP no repositório `ClaudioAlvesJunior/poe-leveling-overlay`. Passe as notas daquela versão em um arquivo Markdown para `gh release create --notes-file`. Mantenha o nome `NerdMiticoJr-PoE-Leveling-Overlay.zip` em cada versão.
5. Confira o download na [versão mais recente](https://github.com/ClaudioAlvesJunior/poe-leveling-overlay/releases/latest), o commit da tag e a página de histórico.

A Wiki versionada está em [`docs/`](README.md). Se a aba Wiki do GitHub estiver inicializada, mantenha a página inicial apontando para a documentação atual do repositório.
