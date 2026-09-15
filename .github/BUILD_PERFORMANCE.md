# Builds e caches

## Diagnóstico medido

Execuções consultadas em 14/09/2026:

- [Release v1.5.3 — 19min19s](https://github.com/SamuelMoraesF/usra-r3-app/actions/runs/34902528827)
- [Release v1.5.2 — 18min27s](https://github.com/SamuelMoraesF/usra-r3-app/actions/runs/34899441796)
- [CI anterior — 5min32s](https://github.com/SamuelMoraesF/usra-r3-app/actions/runs/34902302290)

Na v1.5.3:

| Etapa | Tempo |
| --- | --- |
| Windows: instalação do Flutter e dependências | 3min24s |
| Windows: compilação | 7min03s |
| Windows: salvamento de caches ao final | 6min29s |
| Android: restauração/configuração do Gradle | 1min27s |
| Android: APK assinado | 5min19s |
| Web: compilação, depois do Android | 1min25s |
| Web: deploy | 38s |
| Linux: compilação | 3min09s |
| macOS: compilação | 1min42s |
| Publicação: download e envio dos artefatos | 1min38s |

O Windows determinava o tempo total. O salvamento do SDK sozinho consumiu
6min03s, e o log mostrava cache miss para SDK e Pub. O inventário de caches
confirmou Windows/macOS somente nas referências das releases, sem cópias na
`main`. A v1.5.2 também gastou aproximadamente sete minutos salvando os caches
do Windows. Aumentar o paralelismo de Android/Web, sozinho, não resolveria isso.

O Gradle já tinha cache de dependências na `main`, mas faltava habilitar
`org.gradle.caching=true` para reaproveitar saídas das tarefas compatíveis.
As releases restauravam o cache em modo somente leitura. O CI compilava apenas
Android/Web, enquanto as releases também compilavam os três desktops.

## Estrutura nova

- CI e Release usam o mesmo `build-platform.yml` para as cinco plataformas.
- Android, Web, Linux, Windows, macOS e verificações de qualidade executam em
  paralelo. A disponibilidade de runners ainda pode impor espera.
- A montagem do ZIP histórico depende somente de Android e Web.
- O deploy Web depende de Web e qualidade. A publicação da release depende de
  qualidade, bundle, todos os desktops e deploy Web (quando configurado).
- Push de tag `v*` dispara a release. `workflow_dispatch` permite repetir uma
  tag existente. O evento `release.published` foi removido porque disparava uma
  segunda execução para cada tag, cancelando a primeira.

## Caches

| Cache | Chave/invalidação | Escrita |
| --- | --- | --- |
| Flutter SDK | SO, arquitetura e versão/hash do SDK | CI na `main`, em caso de miss |
| Pub | SO, arquitetura, Flutter e `pubspec.lock`, com fallback para dependências anteriores | CI na `main` |
| Gradle | Gerenciado por `setup-gradle`, com cache de tarefas habilitado | CI na `main` |
| Dependências nativas | SO, arquitetura, imagem do runner, lockfile e configuração nativa/SDK | CI na `main` |
| build_runner | SDK/configuração, lockfile e commit, com fallback por lockfile | CI na `main` |

As outras execuções apenas restauram. Isso também vale para uma release manual
disparada na `main`. Evita recomprimir SDKs grandes em tags sem possibilidade de
reuso entre releases. O CI agora compila desktops e aquece seus caches na branch
que as tags podem consultar.

O cache nativo inclui `_deps` do CMake (downloads e bibliotecas de dependências,
como Sentry/Crashpad), além dos downloads SwiftPM/CocoaPods no macOS. Não inclui
APK assinado, keystore, executável final ou a árvore inteira de build. As saídas
da aplicação são sempre reconstruídas. A chave muda com a imagem do runner para
não reutilizar objetos de um toolchain diferente.

O build usa `--no-pub` após o único `pub get --enforce-lockfile`, paralelismo do
Gradle/CMake e `--no-wasm-dry-run` no Web, que distribui JavaScript. Pacotes usam
compressão rápida e o upload não comprime novamente os arquivos já empacotados.

Para obter cache quente na primeira release após esta mudança, deixe o CI da
`main` concluir antes de enviar a próxima tag. SDKs novos e imagens novas ainda
geram misses; acompanhar tamanho e evicção dos caches também é necessário.
O download/descompactação do SDK Windows continua tendo custo mesmo com hit.

Referências: [escopo dos caches do GitHub](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching),
[cache de tarefas Gradle](https://docs.gradle.org/current/userguide/build_cache.html).

## Arquivos e checksums

Os nomes existentes são mantidos; o Web ganha também um pacote independente.
Exemplo para `v1.5.4`:

| Pacote | Checksum SHA-256 |
| --- | --- |
| `usra-r3-app-v1.5.4.apk` | `SHA256SUMS-usra-r3-app-v1.5.4-android.txt` |
| `usra-r3-app-v1.5.4-web.zip` | `SHA256SUMS-usra-r3-app-v1.5.4-web.txt` |
| `usra-r3-app-v1.5.4-linux.tar.gz` | `SHA256SUMS-usra-r3-app-v1.5.4-linux.txt` |
| `usra-r3-app-v1.5.4-windows.zip` | `SHA256SUMS-usra-r3-app-v1.5.4-windows.txt` |
| `usra-r3-app-v1.5.4-macos.zip` | `SHA256SUMS-usra-r3-app-v1.5.4-macos.txt` |
| `usra-r3-app-v1.5.4.zip` (Web + fonte + APK) | `SHA256SUMS-v1.5.4.txt` |

Cada manifesto lista um único pacote, pelo nome, sem o prefixo `dist/`.
O manifesto histórico `SHA256SUMS-v1.5.4.txt` agora verifica somente o ZIP
combinado; o APK tem seu próprio manifesto. Basta colocar o pacote e seu
checksum na mesma pasta e executar `sha256sum -c NOME-DO-CHECKSUM.txt`.
O workflow verifica os checksums antes do bundle, deploy e publicação.

No CI, continuam `build-android`/`app-debug.apk` e `build-web` com o site na raiz.
Cada artefato recebe `SHA256SUMS-PLATAFORMA.txt`; para o site descompactado, o
manifesto lista cada arquivo. Desktops recebem `build-linux`, `build-windows` e
`build-macos`.

## Validação e próxima medição

`tool/test_package_build.py` verifica nomes, checksums, arquivos corrompidos,
estrutura do bundle, permissões executáveis e links simbólicos do macOS.
`actionlint` valida os workflows localmente.

Os tempos acima são a linha de base, não medições do workflow alterado. Compare
a primeira execução (cache frio) e uma segunda com cache quente, incluindo
setup, restore/save, compilação, empacotamento e publicação. O resultado esperado
é eliminar a gravação de 6–7 minutos de cache no caminho da release e a espera
do Web pelo Android. O ganho de compilação depende dos hits reais do cache de
tarefas/dependências; não há garantia de um tempo final antes de executar no CI.
