# Padrão de sintaxe da inserção rápida

A inserção rápida transforma uma única linha em um contato da sessão de rede
selecionada na tela. Os tokens são separados por um ou mais espaços e não
precisam seguir uma ordem fixa, com exceção do indicativo, que deve ser o
primeiro token, e da mensagem de tráfego, que fica entre marcadores `X`.

## Forma mínima

```text
INDICATIVO NOME GRID POTÊNCIA ESTAÇÃO ENERGIA TRÁFEGO VIA INDICATIVO
```

Exemplo completo sem mensagem:

```text
PY3SC SAMUEL GG30CH 5W PORT BAT ST VIA PY3MM
```

O registro só é habilitado quando todos os campos obrigatórios estiverem
presentes: indicativo, nome, grid Maidenhead válido, potência positiva, estação,
energia, tráfego e `VIA` com indicativo após ele.

## Tokens reconhecidos

| Token | Resultado | Regras |
| --- | --- | --- |
| primeiro token | Indicativo | É convertido para maiúsculas. Deve existir. |
| texto livre | Nome | Tokens não reconhecidos fora da mensagem formam o nome, preservando espaços entre palavras. |
| grid Maidenhead | Localização | É normalizado para maiúsculas e validado. Exemplos: `GG30CH`, `GG30CH12`. |
| `5W` ou `5 W` | Potência | Aceita ponto ou vírgula decimal; deve ser finita e maior que zero. |
| `MOVEL`, `MOV` | Estação móvel | Salva como `M`. |
| `PORT`, `POR`, `PORTATIL`, `HT` | Estação portátil | Salva como `P`. |
| `FIXA`, `BASE` | Estação fixa | Salva como `F`. |
| `BAT` | Bateria | Salva como `B`. |
| `GER` | Gerador | Salva como `G`. |
| `AC` | Rede elétrica | Salva como `AC`. |
| `ST` | Sem tráfego | Salva como `S`. |
| `VIA INDICATIVO` | Relay | Define a estação intermediária. Pode aparecer antes ou depois da mensagem. |
| `X mensagem X` | Com tráfego | Salva `C` e tudo entre os dois `X` vira a mensagem. |

Tokens reconhecidos não diferenciam maiúsculas e minúsculas. A interface
normalmente converte a entrada para maiúsculas, mas o parser também aceita
entrada minúscula.

## Regras de tráfego

`ST` informa que a estação está sem tráfego. Para registrar tráfego, abra a
mensagem com `X`, escreva o conteúdo e encerre com outro `X`:

```text
PY3SC SAMUEL GG30CH 5W PORT BAT X APOIO TECNICO NO CAMOBI X VIA PY3MM
```

O texto pode conter palavras como `VIA`, `ST`, `10W`, `GG30CH` ou `FIXA`: dentro
da região entre `X`, tudo é tratado como mensagem. O `VIA` só é interpretado
como relay fora da mensagem.

O primeiro `X` alterna para o modo de mensagem; o segundo encerra esse modo.
Uma mensagem vazia é inválida. Se o segundo `X` for omitido, o restante da
linha ainda é tratado como mensagem pelo parser; use sempre o marcador de
fechamento para evitar ambiguidades e manter a sintaxe legível.

## Ordem e exemplos

Os campos podem ser reorganizados:

```text
PY3SC 5 W BASE SAMUEL GG30CH AC ST VIA PY3MM
```

O nome é tudo que permanecer sem reconhecimento antes ou depois dos demais
tokens. Portanto, evite usar no nome palavras reservadas (`BAT`, `ST`, `VIA`,
`X`, aliases de estação/energia) quando elas não forem destinadas ao campo
correspondente.

Também é válido colocar o relay depois da mensagem:

```text
PY3SC SAMUEL GG30CH 5W HT GER X MENSAGEM DE TREINO X VIA PY3MM
```

## Erros comuns

- `VIA` sem um indicativo seguinte gera erro e não permite registrar;
- grid com aparência de Maidenhead, mas inválido, gera erro;
- potência sem `W` (`5`) só é aceita quando o próximo token é `W`;
- ausência de `ST` ou de um bloco `X ... X` deixa o tráfego incompleto;
- `X` sem mensagem gera o erro “Informe a mensagem após X.”;
- o parser não valida se o indicativo existe ou se a estação realmente ouviu o
  relay; esses dados devem ser conferidos pelo operador.

## O que acontece ao registrar

O contato é salvo com a frequência atualmente selecionada na tela (`repeater`
ou `simplex`), os defaults de frequência do aplicativo, a sessão aberta e o
grid do operador configurado no perfil. A inserção rápida não abre uma rede,
não encerra uma rede e não transmite nada pelo rádio.
