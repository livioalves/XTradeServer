//+------------------------------------------------------------------+
//|                                                 ThriftClient.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <Indicators\Indicator.mqh>
#include <XTrade\IUtils.mqh>

class IndiBase :  public CIndicator
{
protected:
   bool m_bInited;
   bool bAlreadyExist;
public:
   IndiBase ()
   {
   
      m_bInited = false;
   }
   
   virtual bool Init(ENUM_TIMEFRAMES timeframe) = 0;
   virtual void Process() = 0;
   virtual void Trail(Order &order, int indent) {}
   virtual void Delete() = 0;
   virtual bool Initialized() { return m_bInited; }
   virtual bool Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int num_params,const MqlParam &params[])
   {
       return(true);
   }
   
   bool TrailLevel(Order& order, double ask, double bid, double SL, double TP, double level, double startLevel);
   
   virtual int GetIndicatorData(int BuffIndex, int startPos, int Count, double &Buffer[])
   {
        return CopyBuffer(Handle(), BuffIndex, startPos, Count, Buffer);;
   }

   virtual int       Handle() const 
   {
      return(m_handle);   
   }
   
   virtual bool CheckIndicatorExist(string checkName)
   {
      int i = ChartIndicatorsTotal(0,0);
      int j=0;
      
      while(j < i)
      {
         string IndicatorName = ChartIndicatorName(0,0,j);
         if(StringFind(IndicatorName,checkName) != -1)
         {
            // Utils.Info("<" + IndicatorName + "> Already exists from previous load!");
            bAlreadyExist = true;
            return true;
         }   
         j++;
      }
      bAlreadyExist = false;
      return false;
   }

   
   virtual void RaiseMarketSignal(int Value, string Name)
   {
      if (Value < 0)
      {
         Utils.Trade().OpenExpertOrder(OP_SELL, Name);
         return;
      }
      if (Value > 0)
      {
         Utils.Trade().OpenExpertOrder(OP_BUY, Name);
         return;
      }

      /*Signal* signal = new Signal(SignalToExpert, SIGNAL_MARKET_EXPERT_ORDER, Utils.Service().MagicNumber());
      signal.Value = Value;
      signal.SetName(Name);
      Utils.Service().PostSignalLocally(signal);
      */
      //Utils.Info("Expert Orders Disabled!");
   }
};

bool IndiBase::TrailLevel(Order& order, double ask, double bid, double SL, double TP, double level, double startLevel)
{
    double td = Utils.Trade().TrailDelta();
    if (order.type == OP_BUY)
    {
       double newSL = NormalizeDouble(level - td, _Digits);
       if ( newSL > startLevel)
       {
           order.setStopLoss(newSL);
           return true;
       }
    }
    
    if (order.type == OP_SELL)
    {
       double newSL = NormalizeDouble(level + td, _Digits);
       if ( newSL < startLevel)
       {
           order.setStopLoss(newSL);
           return true;
       }
    }
    return false;
}
