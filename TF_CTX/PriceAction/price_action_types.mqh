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
   int period;
   CTrendLinesConfig(){ period=0; }
  };

#endif // __PRICE_ACTION_CONFIG_TYPES_MQH__
