//+------------------------------------------------------------------+
//|                                         indicators/indicator_base_defs.mqh |
//|  Definitions for CIndicatorBase and related functionalities       |
//+------------------------------------------------------------------+
#ifndef __INDICATOR_BASE_DEFS_MQH__
#define __INDICATOR_BASE_DEFS_MQH__

enum COPY_METHOD
{
  // 0 - BASE_LINE, 1 - UPPER_BAND, 2 - LOWER_BAND, 3 - WIDTH
  COPY_MIDDLE = 0,
  COPY_UPPER = 1,
  COPY_LOWER = 2,
  COPY_WIDTH = 3
};

#endif // __INDICATOR_BASE_DEFS_MQH__
