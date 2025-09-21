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

// Default width history size
#define WIDTH_HISTORY 100

// Default lookback periods
#define WIDTH_LOOKBACK 100
#define SLOPE_LOOKBACK 9

// Default percentile thresholds
#define PERCENTILE_THRESHOLD_VERY_NARROW 10
#define PERCENTILE_THRESHOLD_NARROW 30
#define PERCENTILE_THRESHOLD_NORMAL 70
#define PERCENTILE_THRESHOLD_WIDE 90

// Default weights for combined signal
#define WEIGHT_BAND 0.4
#define WEIGHT_SLOPE 0.3
#define WEIGHT_WIDTH 0.3

// Width region classification
enum ENUM_WIDTH_REGION
{
  WIDTH_VERY_NARROW,
  WIDTH_NARROW,
  WIDTH_NORMAL,
  WIDTH_WIDE,
  WIDTH_VERY_WIDE
};

// Market phase classification
enum ENUM_MARKET_PHASE
{
  PHASE_CONTRACTION,
  PHASE_NORMAL,
  PHASE_EXPANSION
};

// Slope state classification
enum ENUM_SLOPE_STATE
{
  SLOPE_EXPANDING,
  SLOPE_CONTRACTING,
  SLOPE_STABLE
};

// Combined signal structure
struct SCombinedSignal
{
  double confidence;
  string direction;
  string reason;
  ENUM_WIDTH_REGION region;
  ENUM_SLOPE_STATE slope_state;
};

#endif // __BOLLINGER_DEFS_MQH__
