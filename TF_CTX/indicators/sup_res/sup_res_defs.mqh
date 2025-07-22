#ifndef __SUP_RES_DEFS_MQH__
#define __SUP_RES_DEFS_MQH__

// Types for support/resistance lines
enum ENUM_SUPRES_LINE
  {
   SUP_LINE = 0,
   RES_LINE = 1
  };

// Validation modes for support/resistance
enum ENUM_SUPRES_VALIDATION
  {
   SUPRES_VALIDATE_TOUCHES   = 0, // only count touches
   SUPRES_VALIDATE_PATTERNS  = 1, // require price action pattern
   SUPRES_VALIDATE_BOTH      = 2  // touches and price action
  };

#endif // __SUP_RES_DEFS_MQH__
