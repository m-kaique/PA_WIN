#ifndef __TRENDLINE_DEFS_MQH__
#define __TRENDLINE_DEFS_MQH__

// Types of trend lines
enum ENUM_TRENDLINE_SIDE
  {
   TRENDLINE_LTA = 0,
   TRENDLINE_LTB = 1,
   TRENDLINE_LTA2 = 2,
   TRENDLINE_LTB2 = 3
  };

// Position of price relative to trend lines
enum ENUM_TREND_POSITION
  {
   TREND_ABOVE_LTB = 0,  // price above LTB
   TREND_BETWEEN,        // price between LTA and LTB
   TREND_BELOW_LTA,      // price below LTA
   TREND_ABOVE_LTA,      // price above LTA when no LTB
   TREND_BELOW_LTB,      // price below LTB when no LTA
   TREND_UNKNOWN
  };

#endif // __TRENDLINE_DEFS_MQH__
