# USRA R3

Aplicativo Flutter offline-first para registrar, acompanhar e documentar as
operações da Rede de Radiocomunicação Resiliente (R3) da União Santamariense de
Radioamadores (USRA).

## O que é a R3

Uma R3 é uma malha de estações de radioamadores preparada para manter o fluxo
de informações quando energia, internet ou telefonia comercial falham. A
operação é dirigida: a Estação de Controle da Rede (NCS) organiza a frequência,
autoriza as transmissões e prioriza o tráfego; as demais estações permanecem
em escuta, salvo emergência real.

O treinamento da USRA evolui de disciplina e check-in na repetidora para teste
em simplex, cópia de radiogramas e um simulado de crise. O aplicativo dá
suporte documental a esse processo, mas não substitui o operador, o NCS, o
roteiro de operação nem a autorização para transmitir.

## O que o aplicativo faz

- mantém o perfil local do operador (indicativo, nome e grid Maidenhead);
- abre e encerra uma sessão de rede, impedindo novos registros depois do
  encerramento;
- registra contatos na repetidora ou em simplex, com frequência, via/relay,
  localização, potência, tipo de estação, fonte de energia e tráfego;
- mantém os dados em SQLite local via Drift, inclusive no Web;
- mostra no mapa offline o operador, repetidora, estações e rotas de contato,
  com filtros por frequência, validade temporal, precisão e elevação;
- reaproveita dados do último contato para acelerar check-ins;
- exporta e importa CSV e gera relatório PDF da sessão, incluindo mapas quando
  disponíveis.

Os valores operacionais padrão do produto são repetidora PY3SMA em 145,370 MHz
com deslocamento de -600 kHz e simplex em 146,520 MHz. Eles são defaults do
software; o NCS deve confirmar a frequência válida antes de cada exercício.

## Fluxo recomendado durante uma rede

1. Configure o perfil e o grid do operador.
2. Abra a rede quando o NCS iniciar o exercício.
3. Selecione `Repetidora` ou `Simplex` conforme a fase do roteiro.
4. Registre cada estação após o check-in. Use `Via` para indicar uma estação
   intermediária/retransmissora em simplex.
5. Marque energia, tipo de estação e existência de tráfego com cuidado; esses
   campos são parte do diagnóstico de resiliência.
6. Para tráfego, registre a mensagem recebida sem adivinhar partes inaudíveis.
   A confirmação e a retransmissão continuam sendo feitas por rádio conforme
   o NCS.
7. Feche a rede somente quando o exercício terminar. Depois disso, a sessão
   fica disponível para consulta e exportação.

Mais detalhes do modelo operacional estão em [Operação R3](docs/operacao-r3.md)
e da implementação em [Arquitetura](docs/arquitetura.md).

## Desenvolvimento

Requisitos: Flutter 3.47.3, Dart compatível com o SDK declarado em
`pubspec.yaml` e, para Android, JDK 21.

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

Para desenvolvimento rápido, a inserção rápida aceita uma linha como:

```text
PY3SC SAMUEL GG30CH 5W PORT BAT ST
```

Use `tool/` para tarefas de mapas, empacotamento e assinatura. O processo de
CI, releases, artefatos e backup da chave Android está documentado em
[CI/CD](docs/ci-cd.md).

## Estrutura principal

| Caminho | Responsabilidade |
| --- | --- |
| `lib/main.dart` | ciclo da aplicação, telas, sessão e registro de contato |
| `lib/data/database.dart` | schema Drift, migrações e persistência |
| `lib/data/csv_transfer.dart` | importação/exportação compatível de CSV |
| `lib/data/session_report_pdf.dart` | relatório técnico de uma sessão |
| `lib/map/` | mapa offline, presença, agregação, rotas e elevação |
| `lib/widgets/` | formulário e layout de contatos |
| `test/` | testes unitários, de widgets e de regressão |
| `assets/maps/` | dados locais de mapa e elevação |
| `docs/` | documentação operacional, técnica e de entrega |

## Privacidade e limites

Os registros são locais por padrão. Exportações CSV/PDF podem conter
indicativos, nomes, localizações e mensagens; trate esses arquivos como dados
operacionais e compartilhe-os apenas com autorização. O app não oferece
transmissão de rádio, autenticação de operador, sincronização de servidor ou
garantia de cobertura: a validade do contato depende da operação e da
informação lançada pelo usuário.
