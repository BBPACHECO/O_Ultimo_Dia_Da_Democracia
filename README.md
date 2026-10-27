# O Último Dia da Democracia

Jogo narrativo **nativo para Android**, em português, feito com Godot 4.6.3 e GDScript. Funciona offline, sem navegador, WebView, conta, anúncios ou serviços externos.

## A primeira versão

Na cidade fictícia de Aurora, você assume o último plantão de uma redação independente. Oito decisões, da tarde à meia-noite, mudam a voz pública, as provas reunidas e o risco para a equipe. Suas escolhas levam a diferentes desfechos. O progresso é salvo automaticamente no aparelho; é possível sair e continuar depois.

É um protótipo jogável original. O cenário e os personagens são fictícios.

## Desenvolver

Abra `project.godot` no **Godot 4.6.3 estável**, edição padrão (não precisa de .NET), e pressione F6 na cena principal ou F5 no projeto. A janela de desenvolvimento simula a tela vertical do celular. O jogo instalado usa a interface e o renderizador nativos do engine.

No ambiente de nuvem Linux, o Godot e o Java 21 já estão disponíveis:

```bash
cd /workspace/O_Ultimo_Dia_Da_Democracia
bash tools/setup_android.sh
bash tools/test.sh
bash tools/build_android.sh
```

Os scripts usam `/workspace/.tools/democracia` para SDK, templates, configurações e caches, sem gravar no diretório pessoal do usuário. É possível escolher outro diretório com `GAME_TOOL_ROOT`. Não é necessário npm, servidor HTTP, Gradle ou compilação do engine. A exportação usa templates Android oficiais pré-compilados; por isso, não exige NDK nem CMake. Os downloads têm seus checksums verificados e as conexões mantêm a verificação TLS.

Para abrir o editor em uma sessão Linux com tela:

```bash
source tools/env.sh
godot --path "$PROJECT_ROOT" --editor
```

## Instalar no Android

O build gera `builds/o-ultimo-dia-debug.apk`, compatível com Android 7.0 ou superior e celulares ARM de 32 e 64 bits com OpenGL ES 3.0. Copie o APK para seu aparelho e autorize a instalação para o aplicativo usado para abri-lo. Alternativamente, **no seu computador**, com Android Platform Tools instalado, aparelho conectado e depuração USB autorizada:

```bash
adb install -r builds/o-ultimo-dia-debug.apk
```

É uma versão de desenvolvimento com assinatura de depuração. Publicar na Play Store exige uma chave de lançamento própria e um build AAB, além da preparação da ficha da loja; isso não faz parte deste protótipo. Não inclua keystores de lançamento no Git.

O preset deixa a execução automática por USB no editor desativada (`runnable=false`), para não procurar aparelhos durante a compilação na nuvem. Isso não afeta o ícone nem a execução do aplicativo instalado. A instalação e o uso em um aparelho físico ainda precisam ser verificados.

## Organização

- `data/story.json`: capítulos, textos e consequências.
- `scripts/story_game.gd`: regras, finais e salvamento validado.
- `scripts/main.gd` e `scenes/main.tscn`: interface do jogo para toque.
- `assets/`: arte vetorial original.
- `tests/`: testes do motor e do fluxo da interface, executados pelo próprio Godot.
- `tools/`: instalação reproduzível, testes, exportação e verificação do APK.

O salvamento fica em `user://game_save.json`, no armazenamento privado do aplicativo. Os testes usam arquivos separados do progresso do jogador. `builds/` e `.godot/` são saídas locais ignoradas pelo Git.
