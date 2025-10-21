# Revisão da função `IsValidPullback`

Este documento resume problemas observados na lógica da função `IsValidPullback` implementada em `emas_bull_buy.mqh` e propõe ajustes para corrigi-los.

## 1. Inconsistência de unidades nas comparações com o ATR

O campo `distance` de `SPositionInfo` é preenchido pelo módulo `indicator_candle_distance` em número de pips (diferença dividida pelo valor de pip).【F:TF_CTX/indicators/indicator_base/submodules/indicator_candle_distance/indicator_candle_distance.mqh†L39-L75】 Entretanto, na função `IsValidPullback` essa distância é comparada diretamente com `atr_value`, que está em unidades de preço, ao calcular `max_depth` e nas razões `distance / atr_value`.【F:STRATEGIES/strategies/emas_strategy/emas_bull_buy/emas_bull_buy.mqh†L275-L287】【F:STRATEGIES/strategies/emas_strategy/emas_bull_buy/emas_bull_buy.mqh†L308-L320】 Como resultado, basta que o ATR seja inferior a 1 pip para que o critério 2 falhe sistematicamente, mesmo quando a retração é pequena.

**Solução proposta:** normalizar as unidades antes de comparar. Duas alternativas equivalentes são:

- Converter o ATR para pips (`atr_in_pips = atr_value / pip_value`) e então usar `position_info.distance` diretamente nessas comparações.
- Converter `position_info.distance` para unidades de preço (`distance_price = position_info.distance * pip_value`) e manter o ATR em preço.

Com qualquer abordagem, os critérios 2 e 3 passam a operar sobre grandezas compatíveis, evitando rejeições falsas.

## 2. Distância ausente para posições "on body"

Quando o indicador cruza o corpo do candle (`INDICATOR_CROSSES_UPPER_BODY`, `INDICATOR_CROSSES_LOWER_BODY`, `INDICATOR_CROSSES_CENTER_BODY`), o módulo de distância não atribui um valor a `distance` (mantém o padrão 0).【F:TF_CTX/indicators/indicator_base/submodules/indicator_candle_distance/indicator_candle_distance.mqh†L125-L147】 A função `IsValidPullback` utiliza esse campo para estimar a profundidade atual. Nessas situações, os critérios 2 e 3 acabam avaliando uma distância igual a zero, o que pode fazer o critério 3 aceitar quase qualquer histórico ou, inversamente, impedir a validação quando o preço realmente se afastou da EMA.

**Solução proposta:** calcular uma distância alternativa diretamente na função quando `position_info.distance == 0`, por exemplo `MathAbs(last_close - current_ma)` em preço (ou em pips após normalização). Outra opção é complementar `indicator_candle_distance` para fornecer a distância mesmo quando o indicador cruza o corpo.

## 3. Medida de penetração ignora sombras inferiores

O critério 5 mede a penetração abaixo da EMA usando apenas o preço de fechamento (`last_close`).【F:STRATEGIES/strategies/emas_strategy/emas_bull_buy/emas_bull_buy.mqh†L363-L375】 Em pullbacks típicos, o candle pode fechar acima ou muito próximo da EMA após formar um pavio longo. Quando isso ocorre, a validação considera a penetração igual a zero, mesmo se o fundo da vela tiver ultrapassado a EMA de forma relevante.

**Solução proposta:** utilizar o `iLow` da vela para medir a penetração real (`penetration = MathMax(0, current_ma - last_low)`), ou no mínimo comparar o menor valor entre fechamento e mínima. Assim, o critério passa a considerar a excursão total do preço durante o recuo.

---

Ajustar esses três pontos tende a tornar a validação de pullback mais consistente com o conceito descrito na própria documentação do código, reduzindo falsos negativos e falsos positivos.
