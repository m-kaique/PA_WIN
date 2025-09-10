#ifndef __Tester_QOL_FNS__
#define __Tester_QOL_FNS__

bool IsStrategyTester()
{
   return (bool)MQLInfoInteger(MQL_TESTER);
}

void PersonalizarGrafico()
{
   if (!IsStrategyTester())
      return;

   long chartId = ChartID();

   // Remove grades
   ChartSetInteger(chartId, CHART_SHOW_GRID, false);

   // Configura cores do fundo
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, clrWhite);

   // Configura cores sólidas para velas (verde para alta, vermelho para baixa)
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP, clrLime);    // Corpo das velas de alta
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, clrRed);   // Corpo das velas de baixa
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, clrLime); // Contorno velas de alta
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, clrRed);  // Contorno velas de baixa

   // Garante que as velas serão exibidas como sólidas (preenchidas)
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);

   // Remove volumes e outros elementos opcionais
   ChartSetInteger(chartId, CHART_SHOW_VOLUMES, false);
   ChartSetInteger(chartId, CHART_SHOW_OBJECT_DESCR, false);

   // Configuração extra para garantir velas sólidas
   ChartSetInteger(chartId, CHART_COLOR_STOP_LEVEL, clrLime); // Suporte adicional para cores

   // Atualiza o gráfico para aplicar as mudanças
   ChartRedraw(chartId);

   // Força a atualização imediata do gráfico
   ChartSetSymbolPeriod(chartId, Symbol(), Period());
}

#endif