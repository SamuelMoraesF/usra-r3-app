# Operação R3 e tradução para o aplicativo

## Conceito operacional

A R3 é uma malha independente de estações de radioamadores que busca manter
informações circulando durante falhas de energia, internet ou telefonia. Cada
rodada testa equipamento, antenas, energia alternativa e disciplina dos
operadores.

Na rede dirigida, a NCS organiza a frequência e chama as estações. O restante
da rede fica QRV, em escuta, sem transmitir por iniciativa própria. Tráfego de
emergência real interrompe a rotina e tem prioridade absoluta. O aplicativo
registra o que foi ouvido e confirmado; não decide prioridade nem autoriza
transmissões.

## Quatro etapas do treinamento

| Etapa | Objetivo | Evidência útil no app |
| --- | --- | --- |
| 1. Fundamentos | pontualidade, roteiro, check-in e status da estação na repetidora | sessão `repeater`, estação, energia, potência, localização e tráfego |
| 2. Resiliência | testar alcance sem repetidora e praticar relay | sessão `simplex`, frequência direta e campo `Via` |
| 3. Radiograma | copiar e conferir mensagens estruturadas | `Com tráfego` e texto recebido, sem substituir o formulário ARRL |
| 4. Simulado | combinar QSY, simplex, relay e mensagens sob pressão | sessão completa, relatório PDF, CSV e mapa por frequência |

## Relação entre o roteiro e a tela

- **Abertura:** use `Fazer abertura da rede` quando o NCS abrir o exercício.
  Isso cria o identificador temporal da sessão.
- **Check-in:** registre o indicativo, nome, localização/grid, potência, tipo
  de estação e energia. Se houver mensagem, marque `Com tráfego` e escreva
  somente o que foi copiado.
- **QSY:** altere o segmento para `Simplex` e confirme a frequência definida
  pelo NCS. O valor padrão do produto é 146,520 MHz, mas o roteiro pode
  determinar outra frequência.
- **Relay:** preencha `Via` com o indicativo da estação intermediária. Isso
  permite desenhar a rota operador → relay → estação quando ambos os pontos
  estiverem localizados.
- **Encerramento:** use `Fazer encerramento da rede` após o clearance do NCS.
  Os registros passam a compor o histórico fechado e não recebem novos
  contatos.

## Presença e mapa

O mapa não representa uma garantia de cobertura. Durante uma sessão aberta, a
presença considera o contato mais recente de cada estação, frequência e
indicativo. Por padrão, ele expira após 3 horas e avisa nos 30 minutos finais;
esses limites são configuráveis.

Repetidora e simplex são agrupados separadamente. Linhas de contato só são
desenhadas quando há grids válidos; em repetidora usam a posição registrada da
repetidora e, em simplex, usam `Via` quando a estação intermediária foi
localizada. Um relay não inferido aparece como rota incompleta, nunca como uma
posição inventada.

## Radiogramas

O treinamento usa a estrutura ARRL: preâmbulo, endereço, texto e assinatura,
com contagem de palavras (check). O app guarda o campo de mensagem do tráfego
para auditoria do log, mas não valida nem gera um radiograma formal. Para o
exercício, o operador deve continuar usando o formulário definido pela USRA e
fazer a leitura de volta solicitada pela NCS.

## Segurança operacional

Indicativos, nomes, grids, mensagens e relatórios podem revelar localização e
capacidade de estações. Verifique a autorização antes de exportar ou enviar
CSV/PDF. Em emergência real, siga o NCS e a regulamentação aplicável; esta
documentação não substitui treinamento, licenciamento ou o roteiro oficial.
