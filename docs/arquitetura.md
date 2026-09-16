# Arquitetura do aplicativo

## Visão geral

O projeto é um aplicativo Flutter multiplataforma (Android, iOS, Web, Linux,
Windows e macOS). A interface principal está em `lib/main.dart`, com regras
específicas separadas em módulos de dados, mapa e widgets. O armazenamento é
local e usa Drift sobre SQLite; no Web, o SQLite e o worker são carregados dos
assets `sqlite3.wasm` e `drift_worker.js`.

```text
UI (main.dart/widgets)
        |
        +--> UsraDatabase (Drift/SQLite local) --> LogEntries
        +--> station_presence/contact_scene --> mapa offline
        +--> csv_transfer ---------------------> CSV
        +--> session_report_pdf ---------------> PDF
        +--> SharedPreferences ----------------> perfil, preferências, sessão
```

## Modelo de dados

`LogEntries` é o log de contatos. Além do instante UTC, guarda indicativo,
operador, localização/grid, potência, tipo de estação, energia, tráfego,
mensagem, frequência e relay. `networkStartedAt` e `networkEndedAt` associam
cada contato a uma sessão de rede.

O código persistido de frequência é `repeater` ou `simplex`. O log conserva o
histórico; presença é calculada em tempo de execução por sessão, modo,
frequência e indicativo. O banco está na versão de schema 11 no momento desta
documentação.

## Mapa offline

`lib/map/` transforma logs em uma cena de marcadores e rotas. Os grids são
interpretados pelo locator Maidenhead; arquivos PMTiles e dados de elevação
ficam em `assets/maps/`. O mapa pode mostrar estação do operador, repetidora,
contatos recentes, linhas, precisão e elevação, conforme as preferências.

O mapa não deve criar uma coordenada a partir de uma localização textual nem
misturar histórico de frequências diferentes. Essas propriedades são
importantes para a leitura técnica do alcance.

## Exportação e compatibilidade

O CSV tem cabeçalho versionado por compatibilidade prática: o importador aceita
formatos legados e o formato atual, valida frequência, potência e grids quando
aplicável e normaliza indicativos. O PDF agrupa os contatos por repetidora e
simplex e pode incorporar uma imagem do mapa.

Mudanças em campos de `LogEntries` devem atualizar simultaneamente banco,
migração, CSV, PDF, formulário, mapa e testes. Consulte
[AGENTS.md](../AGENTS.md) para as verificações obrigatórias.
