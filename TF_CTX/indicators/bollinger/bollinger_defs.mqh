#ifndef __BOLLINGER_DEFS_MQH__
#define __BOLLINGER_DEFS_MQH__

// Enumerations for Bollinger Bands indicator

enum ENUM_BOLL_APPLIED_PRICE
{
  BOLL_PRICE_CLOSE = PRICE_CLOSE,
  BOLL_PRICE_OPEN = PRICE_OPEN,
  BOLL_PRICE_HIGH = PRICE_HIGH,
  BOLL_PRICE_LOW = PRICE_LOW,
  BOLL_PRICE_MEDIAN = PRICE_MEDIAN,
  BOLL_PRICE_TYPICAL = PRICE_TYPICAL,
  BOLL_PRICE_WEIGHTED = PRICE_WEIGHTED
};


// --- Movimento das Bandas de Bollinger ---
enum ENUM_BOLL_DIR
{
  BOLL_DIR_DOWN  = -1,
  BOLL_DIR_FLAT  =  0,
  BOLL_DIR_UP    =  1
};

enum ENUM_BOLL_VOL_STATE
{
  BOLL_VOL_CONTRACTING = -1,
  BOLL_VOL_STABLE      =  0,
  BOLL_VOL_EXPANDING   =  1,
  BOLL_VOL_SQUEEZE     = -2  // estado especial (compressão estatística)
};

struct SBollingerMovement
{
  // Métricas brutas
  double slope_middle;
  double slope_upper;
  double slope_lower;
  double width;          // upper - lower na barra 'shift'
  double slope_width;
  double width_mean;     // média na janela
  double width_stdev;    // desvio-padrão na janela
  double width_zscore;   // (width - mean) / stdev (se stdev>0)

  // Classificações
  ENUM_BOLL_DIR       dir;
  ENUM_BOLL_VOL_STATE vol;
};

#endif // __BOLLINGER_DEFS_MQH__
