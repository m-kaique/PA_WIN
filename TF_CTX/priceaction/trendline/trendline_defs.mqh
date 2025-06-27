#ifndef __TRENDLINE_DEFS_MQH__
#define __TRENDLINE_DEFS_MQH__

// Enumerations for TrendLine pattern

enum ENUM_TRENDLINE_TYPE
  {
   TRENDLINE_SUPPORT = 0,    // Linha de suporte (conecta fundos)
   TRENDLINE_RESISTANCE = 1  // Linha de resistência (conecta topos)
  };

enum ENUM_TRENDLINE_STATUS
  {
   TRENDLINE_INVALID = 0,    // Linha de tendência inválida
   TRENDLINE_VALID = 1,      // Linha de tendência válida
   TRENDLINE_BROKEN = 2      // Linha de tendência rompida
  };

#endif // __TRENDLINE_DEFS_MQH__