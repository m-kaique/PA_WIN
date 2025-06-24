//+------------------------------------------------------------------+
//|                                indicators/fibonacci.mqh          |
//|  Fibonacci retracement indicator drawing object                  |
//+------------------------------------------------------------------+
#ifndef __FIBONACCI_MQH__
#define __FIBONACCI_MQH__

#include "indicator_base.mqh"

class CFibonacci : public CIndicatorBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_bars;
   double          m_levels[6];
   double          m_extensions[3];
   color           m_levels_color;
   int             m_levels_style;
   int             m_levels_width;
   color           m_extensions_color;
   int             m_extensions_style;
   int             m_extensions_width;
   color           m_parallel_color;
   int             m_parallel_style;
   int             m_parallel_width;
   string          m_obj_name;
   bool            m_ready;
   bool            m_show_labels;

   void            DeleteObject();
   string          FormatLabel(double percent,double hi,double lo);

public:
                     CFibonacci();
                    ~CFibonacci();

  bool             Init(string symbol, ENUM_TIMEFRAMES timeframe,
                          int bars,
                          double level1,double level2,double level3,
                          double level4,double level5,double level6,
                          color levels_color);
  bool             Init(string symbol, ENUM_TIMEFRAMES timeframe,
                          int bars,
                          double level1,double level2,double level3,
                          double level4,double level5,double level6,
                          color levels_color,
                          ENUM_LINE_STYLE level_style,int level_width,
                          double ext1,double ext2,double ext3,
                          color ext_color,ENUM_LINE_STYLE ext_style,int ext_width,
                          color parallel_color,ENUM_LINE_STYLE parallel_style,int parallel_width,
                          bool show_labels);
   // Interface base (chama Init com níveis padrão)
  virtual bool     Init(string symbol, ENUM_TIMEFRAMES timeframe,
                          int period, ENUM_MA_METHOD method);
  virtual double   GetValue(int shift=0);
  virtual bool     CopyValues(int shift,int count,double &buffer[]);
  virtual bool     IsReady();
  virtual bool     Update();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFibonacci::CFibonacci()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_bars=0;
   ArrayInitialize(m_levels,0.0);
   ArrayInitialize(m_extensions,0.0);
   m_levels_color=clrOrange;
   m_levels_style=STYLE_SOLID;
   m_levels_width=1;
   m_extensions_color=clrOrange;
   m_extensions_style=STYLE_DASH;
   m_extensions_width=1;
   m_parallel_color=clrYellow;
   m_parallel_style=STYLE_SOLID;
   m_parallel_width=1;
   m_obj_name="";
   m_ready=false;
   m_show_labels=true;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFibonacci::~CFibonacci()
  {
   DeleteObject();
  }

//+------------------------------------------------------------------+
//| Delete existing object                                           |
//+------------------------------------------------------------------+
void CFibonacci::DeleteObject()
  {
   if(StringLen(m_obj_name)>0)
     ObjectDelete(0,m_obj_name);
  }

//+------------------------------------------------------------------+
//| Helper to format level label                                     |
//+------------------------------------------------------------------+
string CFibonacci::FormatLabel(double percent,double hi,double lo)
  {
   int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
   double price=hi-(hi-lo)*percent/100.0;
   return(DoubleToString(price,digits)+" "+DoubleToString(percent,1)+"%");
  }

//+------------------------------------------------------------------+
//| Init with custom levels                                          |
//+------------------------------------------------------------------+
bool CFibonacci::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int bars,
                      double level1,double level2,double level3,
                      double level4,double level5,double level6,
                      color levels_color)
  {
   return Init(symbol,timeframe,bars,
               level1,level2,level3,level4,level5,level6,
               levels_color,STYLE_SOLID,1,
               127.0,161.8,261.8,
               clrOrange,STYLE_DASH,1,
               clrYellow,STYLE_SOLID,1,true);
  }

//+------------------------------------------------------------------+
//| Init with full customization                                     |
//+------------------------------------------------------------------+
bool CFibonacci::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int bars,
                      double level1,double level2,double level3,
                      double level4,double level5,double level6,
                      color levels_color,
                      ENUM_LINE_STYLE level_style,int level_width,
                      double ext1,double ext2,double ext3,
                      color ext_color,ENUM_LINE_STYLE ext_style,int ext_width,
                      color parallel_color,ENUM_LINE_STYLE parallel_style,int parallel_width,
                      bool show_labels)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_bars=bars;
   m_levels[0]=level1;
   m_levels[1]=level2;
   m_levels[2]=level3;
   m_levels[3]=level4;
   m_levels[4]=level5;
   m_levels[5]=level6;
   m_levels_color=levels_color;
   m_levels_style=level_style;
   m_levels_width=level_width;
   m_extensions[0]=ext1;
   m_extensions[1]=ext2;
   m_extensions[2]=ext3;
   m_extensions_color=ext_color;
   m_extensions_style=ext_style;
   m_extensions_width=ext_width;
   m_parallel_color=parallel_color;
   m_parallel_style=parallel_style;
   m_parallel_width=parallel_width;
   m_show_labels=show_labels;

   if(StringLen(m_obj_name)==0)
      m_obj_name="Fibo_"+IntegerToString(GetTickCount());

   return Update();
  }

//+------------------------------------------------------------------+
//| Interface base implementation                                    |
//+------------------------------------------------------------------+
bool CFibonacci::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, ENUM_MA_METHOD method)
  {
   double defaults[6]={23.6,38.2,50.0,61.8,78.6,100.0};
   return Init(symbol,timeframe,period,
               defaults[0],defaults[1],defaults[2],
               defaults[3],defaults[4],defaults[5],
               clrOrange,STYLE_SOLID,1,
               127.0,161.8,261.8,
               clrOrange,STYLE_DASH,1,
               clrYellow,STYLE_SOLID,1,true);
  }

//+------------------------------------------------------------------+
//| No value returned                                                |
//+------------------------------------------------------------------+
double CFibonacci::GetValue(int shift)
  {
   return 0.0;
  }

//+------------------------------------------------------------------+
//| Not applicable                                                   |
//+------------------------------------------------------------------+
bool CFibonacci::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,0);
   return false;
  }

//+------------------------------------------------------------------+
//| Ready status                                                     |
//+------------------------------------------------------------------+
bool CFibonacci::IsReady()
  {
   return m_ready;
  }

//+------------------------------------------------------------------+
//| Recalculate and redraw Fibonacci levels                          |
//+------------------------------------------------------------------+
bool CFibonacci::Update()
  {
   DeleteObject();

   double highs[]; double lows[];
   if(CopyHigh(m_symbol,m_timeframe,0,m_bars,highs)<=0)
      return false;
   if(CopyLow(m_symbol,m_timeframe,0,m_bars,lows)<=0)
      return false;

   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   int hi_index=ArrayMaximum(highs); int lo_index=ArrayMinimum(lows);
   double hi=highs[hi_index]; double lo=lows[lo_index];
   datetime hi_time=iTime(m_symbol,m_timeframe,hi_index);
   datetime lo_time=iTime(m_symbol,m_timeframe,lo_index);

   if(StringLen(m_obj_name)==0)
      m_obj_name="Fibo_"+IntegerToString(GetTickCount());
   if(!ObjectCreate(0,m_obj_name,OBJ_FIBO,0,hi_time,hi,lo_time,lo))
      return false;

   ObjectSetInteger(0,m_obj_name,OBJPROP_COLOR,m_parallel_color);
   ObjectSetInteger(0,m_obj_name,OBJPROP_STYLE,m_parallel_style);
   ObjectSetInteger(0,m_obj_name,OBJPROP_WIDTH,m_parallel_width);

   double vals[9]; color cols[9]; int styles[9]; int widths[9]; string texts[9];
   int cnt=0;
   for(int i=0;i<6;i++)
     if(m_levels[i]!=0.0)
       {
        vals[cnt]=m_levels[i];
        cols[cnt]=m_levels_color;
        styles[cnt]=m_levels_style;
        widths[cnt]=m_levels_width;
        texts[cnt]=m_show_labels?FormatLabel(m_levels[i],hi,lo):"";
        cnt++;
       }
   for(int i=0;i<3;i++)
     if(m_extensions[i]!=0.0)
       {
        vals[cnt]=m_extensions[i];
        cols[cnt]=m_extensions_color;
        styles[cnt]=m_extensions_style;
        widths[cnt]=m_extensions_width;
        texts[cnt]=m_show_labels?FormatLabel(m_extensions[i],hi,lo):"";
        cnt++;
       }

   ObjectSetInteger(0,m_obj_name,OBJPROP_LEVELS,cnt);
   for(int i=0;i<cnt;i++)
     {
      ObjectSetDouble(0,m_obj_name,OBJPROP_LEVELVALUE,i,vals[i]);
      ObjectSetInteger(0,m_obj_name,OBJPROP_LEVELCOLOR,i,cols[i]);
      ObjectSetInteger(0,m_obj_name,OBJPROP_LEVELSTYLE,i,styles[i]);
      ObjectSetInteger(0,m_obj_name,OBJPROP_LEVELWIDTH,i,widths[i]);
      if(m_show_labels)
         ObjectSetString(0,m_obj_name,OBJPROP_LEVELTEXT,i,texts[i]);
     }

   m_ready=true;
   return true;
  }

#endif // __FIBONACCI_MQH__
