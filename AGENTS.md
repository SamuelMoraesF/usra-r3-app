# Orientações do projeto USRA R3

## Contexto do domínio

Este repositório contém o aplicativo Flutter offline-first usado como logbook
da Rede de Radiocomunicação Resiliente da USRA. A rede é uma rede dirigida:
NCS controla a frequência, estações aguardam autorização e emergência real tem
prioridade. Consulte [docs/operacao-r3.md](docs/operacao-r3.md) antes de alterar
campos, telas ou relatórios ligados à operação.

O aplicativo registra evidências do exercício; ele não é um controlador de
rádio. Não transformar o formulário em instrução para transmitir, inventar
dados de cobertura ou confundir `Via` com uma estação automaticamente ouvida.

## Regras de implementação

- Preserve o funcionamento offline: persistência principal fica no SQLite local
  via Drift; rede deve ser opcional para atualização, observabilidade e mapas.
- Mantenha datas persistidas em UTC. A apresentação pode usar Brasília ou UTC,
  mas não aplique o fuso do dispositivo ao importar ou migrar registros.
- `repeater` e `simplex` são valores de domínio persistidos. Ao alterar
  frequências, defaults ou códigos, revise migrações, CSV, PDF, mapa e testes.
- Não descarte histórico ao deduplicar presença: contatos são imutáveis como
  log, enquanto presença é uma projeção temporal da sessão, frequência e
  indicativo.
- Valide grids Maidenhead quando o valor tiver aparência de grid, sem impedir
  a anotação de uma localização textual comum.
- Alterações no schema Drift exigem atualização de `schemaVersion`, migração,
  arquivo gerado quando necessário e testes de compatibilidade.
- Não inclua chaves, credenciais, DSNs ou arquivos `.release-signing/` em
  commits, pacotes, documentação ou exemplos reais.

## Verificação antes de concluir

Execute, conforme o escopo da mudança:

```bash
flutter format --set-exit-if-changed lib test
flutter analyze
flutter test
python3 -m unittest discover -s tool -p '*test*.py'
```

Para mudanças de CI/release, leia [docs/ci-cd.md](docs/ci-cd.md) e valide
também os scripts de `tool/`. Preserve alterações locais preexistentes e não
use comandos destrutivos para “limpar” o worktree.

## Organização

- lógica de dados e migrações: `lib/data/`;
- regras de presença, alcance e mapa: `lib/map/`;
- interface e fluxo da sessão: `lib/main.dart` e `lib/widgets/`;
- testes correspondentes em `test/`;
- documentação operacional e técnica em `docs/`.
