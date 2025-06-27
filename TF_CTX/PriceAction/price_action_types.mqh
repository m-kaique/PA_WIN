//+------------------------------------------------------------------+
//|                                         price_action_types.mqh   |
//|  OOP Price Action configuration types                            |
//+------------------------------------------------------------------+
#ifndef __PRICE_ACTION_CONFIG_TYPES_MQH__
#define __PRICE_ACTION_CONFIG_TYPES_MQH__

class CPriceActionConfig
  {
public:
   string name;
   string type;
   bool   enabled;
   virtual ~CPriceActionConfig(){}
  };

class CTrendLinesConfig : public CPriceActionConfig
  {
public:
   int  period;
   int  left;
   int  right;
   CTrendLinesConfig(){ period=21; left=3; right=3; }
  };

#endif // __PRICE_ACTION_CONFIG_TYPES_MQH__
