//+------------------------------------------------------------------+
//|                                    priceAction/trend_lines.mqh    |
//|  Detects basic trend lines (LTA and LTB)                          |
//+------------------------------------------------------------------+
#ifndef __TREND_LINES_MQH__
#define __TREND_LINES_MQH__

#include "../price_action_base.mqh"
#include "../price_action_types.mqh"
#include "trend_lines_defs.mqh"

class CTrendLines : public CPriceActionBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;
   int             m_fr_handle;
   bool            m_ready;
   string          m_lta_name;
   string          m_ltb_name;

   void            ReleaseHandle()
                    {
                     if(m_fr_handle!=INVALID_HANDLE)
                       {
                        IndicatorRelease(m_fr_handle);
                        m_fr_handle=INVALID_HANDLE;
                       }
                    }
   void            DeleteObjects()
                    {
                     if(StringLen(m_lta_name)>0) ObjectDelete(0,m_lta_name);
                     if(StringLen(m_ltb_name)>0) ObjectDelete(0,m_ltb_name);
                    }
public:
                    CTrendLines()
                      {
                       m_symbol="";
                       m_timeframe=PERIOD_CURRENT;
                       m_period=21;
                       m_fr_handle=INVALID_HANDLE;
                       m_ready=false;
                       m_lta_name="";
                       m_ltb_name="";
                      }
                   ~CTrendLines()
                      {
                       ReleaseHandle();
                       DeleteObjects();
                      }
   bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
                      {
                       m_symbol=symbol;
                       m_timeframe=timeframe;
                       m_period=period;
                       ReleaseHandle();
                       DeleteObjects();
                       m_fr_handle=iFractals(m_symbol,m_timeframe);
                       m_ready=false;
                       return (m_fr_handle!=INVALID_HANDLE);
                      }
   bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLinesConfig &config)
                      {
                       return Init(symbol,timeframe,config.period);
                      }
   bool            Update()
                      {
                       if(m_fr_handle==INVALID_HANDLE)
                          return false;
                       int bars=m_period+5;
                       double hi_buf[]; double lo_buf[];
                       ArraySetAsSeries(hi_buf,true);
                       ArraySetAsSeries(lo_buf,true);
                       if(CopyBuffer(m_fr_handle,0,0,bars,hi_buf)<=0)
                          return false;
                       if(CopyBuffer(m_fr_handle,1,0,bars,lo_buf)<=0)
                          return false;
                       int low1=-1,low2=-1,high1=-1,high2=-1;
                       for(int i=2;i<bars;i++)
                         if(lo_buf[i]!=0.0)
                           {
                            if(low1==-1) low1=i;
                            else {low2=low1; low1=i; break;}
                           }
                       for(int i=2;i<bars;i++)
                         if(hi_buf[i]!=0.0)
                           {
                            if(high1==-1) high1=i;
                            else {high2=high1; high1=i; break;}
                           }
                       m_ready=false;
                       DeleteObjects();
                       if(low2!=-1 && low1!=-1 && lo_buf[low1]>lo_buf[low2])
                         {
                          if(StringLen(m_lta_name)==0) m_lta_name="LTA_"+IntegerToString(GetTickCount());
                          datetime t1=iTime(m_symbol,m_timeframe,low1);
                          datetime t2=iTime(m_symbol,m_timeframe,low2);
                          double   p1=lo_buf[low1];
                          double   p2=lo_buf[low2];
                          ObjectCreate(0,m_lta_name,OBJ_TREND,0,t2,p2,t1,p1);
                          ObjectSetInteger(0,m_lta_name,OBJPROP_COLOR,clrLime);
                          m_ready=true;
                         }
                       if(high2!=-1 && high1!=-1 && hi_buf[high1]<hi_buf[high2])
                         {
                          if(StringLen(m_ltb_name)==0) m_ltb_name="LTB_"+IntegerToString(GetTickCount());
                          datetime h1=iTime(m_symbol,m_timeframe,high1);
                          datetime h2=iTime(m_symbol,m_timeframe,high2);
                          double   hp1=hi_buf[high1];
                          double   hp2=hi_buf[high2];
                          ObjectCreate(0,m_ltb_name,OBJ_TREND,0,h2,hp2,h1,hp1);
                          ObjectSetInteger(0,m_ltb_name,OBJPROP_COLOR,clrRed);
                          m_ready=true;
                         }
                       return m_ready;
                      }
   bool            IsReady(){ return m_ready; }
  };

#endif // __TREND_LINES_MQH__
