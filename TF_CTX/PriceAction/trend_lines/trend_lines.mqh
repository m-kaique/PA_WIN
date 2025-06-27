//+------------------------------------------------------------------+
//|                                    priceAction/trend_lines.mqh    |
//|  Detects basic trend lines (LTA and LTB)                          |
//+------------------------------------------------------------------+
#ifndef __TREND_LINES_MQH__
#define __TREND_LINES_MQH__

#include "../price_action_base.mqh"
#include "../price_action_types.mqh"
#include "trend_lines_defs.mqh"
#include <Arrays/ArrayObj.mqh>

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
  int             m_left;
  int             m_right;

  // Structure to hold swing points
  class PivotPoint : public CObject
    {
     public:
      int    index;
      double price;
      PivotPoint(int i=0,double p=0.0){ index=i; price=p; }
    };

  CArrayObj      m_swingHighs;
  CArrayObj      m_swingLows;

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
  void            ClearPivots()
                    {
                     for(int i=0;i<m_swingHighs.Total();i++)
                       delete m_swingHighs.At(i);
                     m_swingHighs.Clear();
                     for(int i=0;i<m_swingLows.Total();i++)
                       delete m_swingLows.At(i);
                     m_swingLows.Clear();
                    }
  bool            IsSwingHigh(int index,int left,int right)
                    {
                     double val=iHigh(m_symbol,m_timeframe,index);
                     for(int i=index-left;i<index;i++)
                        if(iHigh(m_symbol,m_timeframe,i)>=val) return false;
                     for(int i=index+1;i<=index+right;i++)
                        if(iHigh(m_symbol,m_timeframe,i)>=val) return false;
                     return true;
                    }
  bool            IsSwingLow(int index,int left,int right)
                    {
                     double val=iLow(m_symbol,m_timeframe,index);
                     for(int i=index-left;i<index;i++)
                        if(iLow(m_symbol,m_timeframe,i)<=val) return false;
                     for(int i=index+1;i<=index+right;i++)
                        if(iLow(m_symbol,m_timeframe,i)<=val) return false;
                     return true;
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
                       m_left=3;
                       m_right=3;
                      }
                   ~CTrendLines()
                      {
                       ReleaseHandle();
                       DeleteObjects();
                       ClearPivots();
                      }
  bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
                      {
                       m_symbol=symbol;
                       m_timeframe=timeframe;
                       m_period=period;
                       ReleaseHandle();
                       DeleteObjects();
                       m_fr_handle=INVALID_HANDLE; // not used with swing logic
                       ClearPivots();
                       m_ready=false;
                       return true;
                      }
  bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLinesConfig &config)
                      {
                       return Init(symbol,timeframe,config.period);
                      }
  bool            Update()
                      {
                       int total=Bars(m_symbol,m_timeframe);
                       int bars=MathMin(total,m_period+m_left+m_right);

                       ClearPivots();
                       for(int i=m_left;i<bars-m_right;i++)
                         {
                          if(IsSwingHigh(i,m_left,m_right))
                             m_swingHighs.Add(new PivotPoint(i,iHigh(m_symbol,m_timeframe,i)));
                          else if(IsSwingLow(i,m_left,m_right))
                             m_swingLows.Add(new PivotPoint(i,iLow(m_symbol,m_timeframe,i)));
                         }

                       m_ready=false;
                       DeleteObjects();

                       for(int i=0;i<m_swingLows.Total()-1 && !m_ready;i++)
                         {
                          PivotPoint *p1=(PivotPoint*)m_swingLows.At(i);
                          for(int j=i+1;j<m_swingLows.Total();j++)
                            {
                             PivotPoint *p2=(PivotPoint*)m_swingLows.At(j);
                             if(p2.index-p1.index<5) continue;
                             if(p2.price>p1.price)
                               {
                                if(StringLen(m_lta_name)==0) m_lta_name="LTA_"+IntegerToString(GetTickCount());
                                datetime t1=iTime(m_symbol,m_timeframe,p1.index);
                                datetime t2=iTime(m_symbol,m_timeframe,p2.index);
                                ObjectCreate(0,m_lta_name,OBJ_TREND,0,t2,p2.price,t1,p1.price);
                                ObjectSetInteger(0,m_lta_name,OBJPROP_COLOR,clrLime);
                                m_ready=true;
                                break;
                               }
                            }
                         }

                       for(int i=0;i<m_swingHighs.Total()-1 && !m_ready;i++)
                         {
                          PivotPoint *p1=(PivotPoint*)m_swingHighs.At(i);
                          for(int j=i+1;j<m_swingHighs.Total();j++)
                            {
                             PivotPoint *p2=(PivotPoint*)m_swingHighs.At(j);
                             if(p2.index-p1.index<5) continue;
                             if(p2.price<p1.price)
                               {
                                if(StringLen(m_ltb_name)==0) m_ltb_name="LTB_"+IntegerToString(GetTickCount());
                                datetime h1=iTime(m_symbol,m_timeframe,p1.index);
                                datetime h2=iTime(m_symbol,m_timeframe,p2.index);
                                ObjectCreate(0,m_ltb_name,OBJ_TREND,0,h2,p2.price,h1,p1.price);
                                ObjectSetInteger(0,m_ltb_name,OBJPROP_COLOR,clrRed);
                                m_ready=true;
                                break;
                               }
                            }
                         }

                       return m_ready;
                      }
   bool            IsReady(){ return m_ready; }
  };

#endif // __TREND_LINES_MQH__
