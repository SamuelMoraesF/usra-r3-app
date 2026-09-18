# CI e releases

O CI executa em pushes na `main`, em pull requests e pelo botão **Run workflow**
em **Actions → CI**. Pelo CLI: `gh workflow run ci.yml --ref main`.
Verifica formatação, análise, testes com cobertura, código gerado pelo Drift e
builds Android debug e Web/Linux/Windows/macOS release em paralelo. Os artefatos
ficam disponíveis por 7 dias, com checksums individuais. CI e Release usam o
mesmo workflow reutilizável de build por plataforma.
Flutter está fixado em 3.47.3; ao atualizar, valide também o `pubspec.lock`.
Os builds Android usam JDK 21, exigido pelo plugin MapLibre, mesmo com o código
do aplicativo configurado para gerar bytecode Java 17.

O CI na `main` aquece os caches de SDK, Pub, Gradle, dependências nativas e
build_runner. Releases e PRs apenas restauram esses caches. Deixe o CI concluir
antes da primeira tag para evitar um build com cache frio.
Veja [tempos medidos, caches e estrutura dos builds](../.github/BUILD_PERFORMANCE.md).

## Distribuir uma versão

### Worker de PDF no navegador

A montagem e compressão do PDF rodam em um Web Worker local, sem enviar dados
para servidores. Android e desktop continuam usando o renderer diretamente.
O arquivo gerado `web/report_pdf_worker.js` é versionado para funcionar também
com `flutter run` e incluído no cache offline. Ao alterar o renderer, o protocolo
ou `tool/report_pdf_worker.dart`, regenere antes de executar/buildar a versão web:

```bash
python3 tool/build_report_worker.py
```

O script aceita `--dart /caminho/para/dart`. O CI recompila automaticamente antes
do build web, inclusive em previews. Não edite o JavaScript gerado manualmente.

### Publicação

Envie uma tag estável `vMAJOR.MINOR.PATCH` para disparar a criação da release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Publicar uma release pelo GitHub não dispara outro build. Para repetir uma tag
existente, use **Actions → Release → Run workflow**, informando a tag, ou
`gh workflow run release.yml --ref main -f tag=v1.0.0 -F benchmark=false`.
O modo `benchmark` (padrão na execução manual) compila o commit selecionado em
`--ref` com a versão informada, sem deploy, publicação ou envio ao Sentry:
`gh workflow run release.yml --ref main -f tag=v1.0.0 -F benchmark=true`.
O código é sempre obtido da tag, não do estado atual da main. Tags de release
devem conter os workflows e não devem ser movidas após a distribuição.
Reexecuções atualizam os anexos da mesma release.

Anexos:

- `usra-r3-app-<tag>.apk`: APK universal assinado, instalável diretamente no Android.
- `usra-r3-app-<tag>.zip`: APK, `web/` pronto para hospedagem e `source/` com os arquivos
  versionados do projeto Flutter. Chaves e senhas não entram no arquivo.
- `usra-r3-app-<tag>-web.zip`: site Web separado.
- `usra-r3-app-<tag>-linux.tar.gz`, `-windows.zip` e `-macos.zip`: aplicativos desktop.
- `SHA256SUMS-usra-r3-app-<tag>-<plataforma>.txt`: checksum individual do pacote.
- `SHA256SUMS-<tag>.txt`: checksum do ZIP combinado, mantendo o nome histórico.

Os checksums usam somente o nome do arquivo, sem `dist/`. Verifique-os com
`sha256sum -c NOME-DO-CHECKSUM.txt` na pasta dos downloads. O workflow também
verifica os pacotes antes de publicá-los.

O nome da versão vem da tag. O versionCode Android é calculado como
`major * 1000000 + minor * 1000 + patch`, permitindo repetir a mesma release sem
mudar a versão. Major deve ser no máximo 2099; minor e patch, no máximo 999.
Use sempre versões crescentes. Não há publicação em lojas. Quando `VERCEL_TOKEN`
está configurado, o Web é implantado automaticamente após passar a qualidade.
Para hospedar em subdiretório, ajuste o `--base-href` do build web.

PRs executam o workflow `Web Preview`: o Flutter Web é compilado no GitHub
Actions e o diretório `build/web` é enviado pela CLI da Vercel sem `--prod`.
Esses deploys pertencem ao ambiente Preview; o ambiente Development da Vercel
continua sendo local. Ao fechar ou fazer merge de uma PR, o workflow remove
somente os Previews marcados com o número daquela PR.

Os artefatos publicados também são enviados automaticamente ao bucket público de
download `usra-r3-releases`, em `https://usra-r3-releases.s3.us-east-1.amazonaws.com/<tag>/<arquivo>`.
O bucket só permite `GetObject` nesses caminhos; listagem, escrita, exclusão e
qualquer acesso sem TLS permanecem bloqueados. A pipeline usa OIDC do GitHub,
sem secret de chave AWS. As políticas reproduzíveis estão em `infra/aws/`.

## Chave de assinatura: backup obrigatório

Foram cadastrados no GitHub os secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Guarde uma cópia **criptografada** de toda a pasta local `.release-signing/`:

- `release.jks`: chave privada usada para assinar o app.
- `credentials.json`: senhas do keystore, da chave e o alias.

A pasta é ignorada pelo Git e criada com acesso restrito ao usuário. Não envie
esses arquivos para o repositório, releases, chats ou armazenamento público.
Os secrets do GitHub não podem ser baixados depois: eles não substituem o backup.
Perder a chave impede atualizar as instalações existentes com a mesma identidade.

O script `python3 tool/setup_android_signing.py` cadastra os secrets usando `gh`;
reutiliza o backup local quando ele existe e recusa gerar outra chave se já
encontrar secrets de assinatura sem backup local.

Os releases usam exclusivamente a chave configurada; não há fallback para a
chave debug. Um APK antigo assinado com debug não aceita atualização pelo APK
de release: exporte os registros antes de desinstalar a versão antiga, pois a
desinstalação remove os dados locais. As próximas versões release poderão ser
instaladas por cima, com a mesma chave e versionCode crescente.

Actions utilizadas: `actions/checkout`, `actions/setup-java`,
`subosito/flutter-action`, `actions/cache`, `gradle/actions/setup-gradle`,
`actions/upload-artifact`, `actions/download-artifact` e
`softprops/action-gh-release`.
