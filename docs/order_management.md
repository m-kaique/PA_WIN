# Sistema de Gerenciamento de Ordens

## Visão Geral da Arquitetura Atual
- **CStrategyBase** concentra o ciclo de vida das estratégias, valida sinais e mantém o estado de execução. Agora delega toda interação com o mercado ao novo `COrderManager`.
- **COrderManager** (arquivo `orders/order_manager.mqh`) encapsula a abertura de posições, aplicação de gerenciamento de risco, monitoramento contínuo das posições e envio de telemetria via socket.
- **Estratégias específicas** (`CEmasBuyBull`, `CEmasBearSell`) configuram requisitos de ordens através do método `ConfigureOrderSettings`, permitindo personalizar o comportamento por estratégia sem duplicar lógica operacional.
- **PROVIDER/provider.mqh** continua responsável pelo transporte UDP (Francis Socket). O `COrderManager` reutiliza essa infraestrutura ao publicar eventos de ordem em formato JSON.

## Requisitos Funcionais do Sistema de Ordens
1. **Abertura de ordens Market** com validação de distância mínima/máxima de stop, cálculo automático de volume e aplicação do *magic number* da estratégia.
2. **Position sizing dinâmico** baseado em percentual de risco sobre o saldo da conta e distância do stop configurada ou inferida.
3. **Risk management por posição** incluindo bloqueio quando o risco agregado excede o limite configurado e normalização automática do lote para as regras do símbolo.
4. **Trailing stop por ATR** com período e multiplicador configuráveis, recalculado continuamente enquanto a posição estiver aberta.
5. **Break-even automático** disparado após atingir o nível de lucro configurado, com offset opcional.
6. **Partial closes** suportando múltiplos níveis em pontos e percentuais relativos, respeitando volume mínimo configurável.
7. **Telemetria de ordens** via socket/cliente de rede, emitindo eventos de abertura, ajustes de stop, break-even, trailing e partial close em JSON com timestamp.
8. **Integração transparente com estratégias**: ao validar um sinal, a estratégia delega a execução ao `COrderManager` e mantém o estado da estratégia sincronizado com o status das posições abertas.

## Fluxo Operacional
1. A estratégia gera e valida um `SStrategySignal`.
2. `CStrategyBase` entrega o sinal ao `COrderManager.OpenMarketOrder`, que calcula o volume e envia a ordem ao servidor.
3. Após a execução, o `COrderManager` registra o ticket, aplica os requisitos de risco e publica evento `open`.
4. A cada atualização (`Update`), o `COrderManager.UpdateOpenPositions`:
   - Verifica limites de risco e atualiza o break-even quando necessário.
   - Calcula o ATR e ajusta trailing stop.
   - Avalia níveis de partial close, executando-os quando atingidos.
   - Publica eventos `break_even`, `trailing` e `partial_close` conforme aplicável.
5. Quando não restarem posições associadas ao *magic number* da estratégia, `CStrategyBase` retorna ao estado `STRATEGY_IDLE`.

## Configuração Padrão
- Os parâmetros padrões residem em `SOrderManagerSettings`. Estratégias podem ajustar `risk_percent`, limites de stop, níveis de partial close, multiplicador ATR, entre outros, no método `ConfigureOrderSettings`.
- As estratégias EMA configuram dois níveis de realização parcial (1R e 2R) e definem risco padrão conforme o JSON de configuração (`risk_percent`).

## Monitoramento e Telemetria
- Cada evento gera um JSON com campos: `type`, `event`, `strategy`, `symbol`, `ticket`, `volume`, `price`, `sl`, `tp`, `details`, `timestamp`.
- Caso um `INetworkClient` esteja disponível, o envio utiliza a interface. Caso contrário, o módulo utiliza `FrancisSocketSend` para broadcast UDP.

## Testes Sugeridos
- Validar a abertura de ordens em conta demo verificando se o volume corresponde ao risco configurado.
- Monitorar o console/log para confirmar eventos `open`, `break_even`, `trailing` e `partial_close`.
- Simular cenários onde o risco agregado excede o limite para garantir que novas ordens sejam bloqueadas corretamente.
