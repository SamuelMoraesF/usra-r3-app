# CI e releases

O CI executa em pushes na `main`, em pull requests e pelo botão **Run workflow**
em **Actions → CI**. Pelo CLI: `gh workflow run ci.yml --ref main`.
Verifica formatação, análise, testes com cobertura, código gerado pelo Drift e
builds Android debug e web release. Os artefatos ficam disponíveis por 7 dias.
Flutter está fixado em 3.47.3; ao atualizar, valide também o `pubspec.lock`.
Os builds Android usam JDK 21, exigido pelo plugin MapLibre, mesmo com o código
do aplicativo configurado para gerar bytecode Java 17.

## Distribuir uma versão

Envie uma tag estável `vMAJOR.MINOR.PATCH` para disparar a criação da release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Publicar uma release pelo GitHub também dispara o workflow para a tag selecionada.
O código é sempre obtido da tag, não do estado atual da main. Tags de release
devem conter os workflows e não devem ser movidas após a distribuição.
Reexecuções atualizam os anexos da mesma release.

Anexos:

- `usra-r3-app.apk`: APK universal assinado, instalável diretamente no Android.
- `usra-r3-app.zip`: APK, `web/` pronto para hospedagem e `source/` com os arquivos
  versionados do projeto Flutter. Chaves e senhas não entram no arquivo.
- `SHA256SUMS`: checksums dos dois arquivos.

O nome da versão vem da tag. O versionCode Android é calculado como
`major * 1000000 + minor * 1000 + patch`, permitindo repetir a mesma release sem
mudar a versão. Major deve ser no máximo 2099; minor e patch, no máximo 999.
Use sempre versões crescentes. Não há publicação em lojas nem hospedagem automática.
Para hospedar em subdiretório, ajuste o `--base-href` do build web.

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
`subosito/flutter-action`, `gradle/actions/setup-gradle`,
`actions/upload-artifact`, `actions/download-artifact` e
`softprops/action-gh-release`.
