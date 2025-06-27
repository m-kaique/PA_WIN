#ifndef __TRENDLINE_DEFS_MQH__
#define __TRENDLINE_DEFS_MQH__

// Enumerations for TrendLine pattern

enum ENUM_TRENDLINE_TYPE
  {
   TRENDLINE_SUPPORT = 0,    // Linha de suporte (conecta fundos) - LTB
   TRENDLINE_RESISTANCE = 1, // Linha de resistência (conecta topos) - LTA
   TRENDLINE_BOTH = 2        // Ambas as linhas
  };

enum ENUM_TRENDLINE_STATUS
  {
   TRENDLINE_INVALID = 0,    // Linha de tendência inválida
   TRENDLINE_VALID = 1,      // Linha de tendência válida
   TRENDLINE_BROKEN = 2      // Linha de tendência rompida
  };

enum ENUM_TRENDLINE_DIRECTION
  {
   TRENDLINE_ASCENDING = 0,  // Linha ascendente (LTA)
   TRENDLINE_DESCENDING = 1, // Linha descendente (LTB)
   TRENDLINE_HORIZONTAL = 2  // Linha horizontal
  };

// Estrutura representando a qualidade de uma linha de tendência
struct TrendLineQuality
  {
   double trend_strength;      // Consistência da direção
   double volume_confirmation; // Volume nos pontos fractais
   double line_tests;          // Quantas vezes preço tocou a linha
   double time_validity;       // Quanto tempo a linha se mantém válida
   double psychological_level; // Proximidade de números redondos
   double volatility_context;  // Relação com volatilidade média
   double mtf_alignment;       // Alinhamento com timeframes maiores

   TrendLineQuality()
     {
      trend_strength=0.0;
      volume_confirmation=0.0;
      line_tests=0.0;
      time_validity=0.0;
      psychological_level=0.0;
      volatility_context=0.0;
      mtf_alignment=0.0;
     }
  };

// Pesos configuráveis para o score final
struct ScoreWeights
  {
   double trend_weight;
   double volume_weight;
   double tests_weight;
   double time_weight;
   double psychological_weight;
   double volatility_weight;
   double mtf_weight;

   ScoreWeights()
     {
      trend_weight=0.25;
      volume_weight=0.15;
      tests_weight=0.20;
      time_weight=0.10;
      psychological_weight=0.10;
      volatility_weight=0.10;
      mtf_weight=0.10;
     }
  };

#endif // __TRENDLINE_DEFS_MQH__