//+------------------------------------------------------------------+
//|                                                 TradeSignals.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <FXMind\InputTypes.mqh>
#include <FXMind\FXMindClient.mqh>

struct Signal 
{
    Signal()
    {
        RaiseTime = 0;
        Handled = false;
        Value = 0;
    }

    bool OnAlert()
    {
       return (!Handled) && (Value != 0);
    }
    datetime RaiseTime;
    bool Handled;
    int Value;
    NewsEventInfo eventInfo;
//    void operator=(const Signal &right) {
//       RaiseTime = right.RaiseTime;
//       Handled = right.Handled;
//       Value = right.Value;
//    }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class TradeSignals 
{
protected:
   FXMindClient* thrift;
   int currentImportance;
   datetime timeNewsPeriodStarted;
   string Symbol;

public:
   Signal Last;
   bool InNewsPeriod;

      TradeSignals(FXMindClient* th) {
         thrift = th;
         currentImportance = MinImportance;
         InNewsPeriod = false;
         timeNewsPeriodStarted = TimeCurrent();
         Last.Handled = true; // first signal is handled!
         Symbol = Symbol();
      }
      
      //~TradeSignals();
     
      //--------------------------------------------------------------------
      bool GetNewsSignal(Signal& signal, string& NewsStatString)
      {   
         datetime currentTime = TimeCurrent();
                                       
         int minsRemained = (int)MathRound((signal.eventInfo.RaiseDateTime - currentTime)/60);
         //if ((!signal.Handled) && (minsRemained <= 0)) // prev signal not handled yet
         //   return false;
                  
         if (InNewsPeriod) 
         {
            int minsNewsPeriod = (int)MathRound((currentTime - timeNewsPeriodStarted)/60);
            if (minsNewsPeriod >= NewsPeriodMinutes)
               InNewsPeriod = false;
         }
         
         string eventString = signal.eventInfo.ToString();
         if (minsRemained < 0)
            eventString = StringFormat("InNews=%s %s Passed %d min ago", (string)InNewsPeriod, eventString, -1*minsRemained);
         else
            eventString = StringFormat("InNews=%s %s Upcoming in %d min", (string)InNewsPeriod, eventString, minsRemained);
         NewsStatString = eventString;
         
         Signal newsignal;
         if (!thrift.GetNextNewsEvent(Symbol(), (ushort)MinImportance, newsignal.eventInfo))
         {
            return false;
         }
         
         minsRemained = (int)MathRound((newsignal.eventInfo.RaiseDateTime - currentTime)/60);

         if (signal.Handled && (newsignal.eventInfo != signal.eventInfo) && (minsRemained >= 0) && (minsRemained <= RaiseSignalBeforeEventMinutes))
         {
            InNewsPeriod = true;
            timeNewsPeriodStarted = currentTime;
            
            signal.Value = newsignal.eventInfo.Importance + 1;
            signal.Handled = false;
            signal.RaiseTime = currentTime;
            signal.eventInfo = newsignal.eventInfo;
            if (!Utils.IsTesting())
               Print(StringFormat("In %d mins News Alert %s", minsRemained, signal.eventInfo.ToString()));
            return true;
         }
         return false;
      }
      
      //+------------------------------------------------------------------+
      int GetBWTrend()
      {
         int signal = 0;
         double isBuy = Utils.iCustom(IndicatorTimeFrame,"BillWilliams_ATZ",   0,0);
         if (isBuy != 0)
            return ++signal;
         double isSell = Utils.iCustom(IndicatorTimeFrame,"BillWilliams_ATZ",   1,0);
         if (isSell != 0)
            return --signal;
         return (signal);   
      }
      //+------------------------------------------------------------------+
      int GetZigZagTrend()
      {
         int n = 0, i;
         double zag = 0, zig = 0;
         i = 0;
         while(n < 2)
         {
            if(zig>0)
             zag=zig;
            zig = Utils.iCustom(IndicatorTimeFrame, "ZigZag", 0, i);
            if(zig>0) n+=1;
            i++;
         }
         if (zag>zig)
           return -1;

         if(zig>zag)
           return 1;
         return 0;   
      }
      //+------------------------------------------------------------------+

      //+------------------------------------------------------------------+
      int GetEMAWMATrend()
      {
         int     signal = 0;
         int     period_EMA           = 28;
         int     period_WMA           = 8;
         int     period_RSI           = 14;
                     
         double EMA0 = Utils.iMA(IndicatorTimeFrame,period_EMA,0,MODE_EMA, PRICE_OPEN,0);
         double WMA0 = Utils.iMA(IndicatorTimeFrame,period_WMA,0,MODE_LWMA,PRICE_OPEN,0);
         double EMA1 = Utils.iMA(IndicatorTimeFrame,period_EMA,0,MODE_EMA, PRICE_OPEN,1);
         double WMA1 = Utils.iMA(IndicatorTimeFrame,period_WMA,0,MODE_LWMA,PRICE_OPEN,1);
         double RSI  = Utils.iRSI(IndicatorTimeFrame,period_RSI,PRICE_OPEN,0);
         //double MFI  = iMFI(NULL,PERIOD_H1,period_RSI,0);
         
         if (EMA0 < WMA0 && EMA1 > WMA1 && RSI >= 50)
            return ++signal;
            
         if (EMA0 > WMA0 && EMA1 < WMA1 && RSI <= 50)
            return --signal;
       
         return (signal);   
      }
      
      //+------------------------------------------------------------------+
      int GetBandsTrend()
      {
         int signal = 0;
      
         double isBuy = Utils.iBands(IndicatorTimeFrame, 20, 2, 0, PRICE_LOW, MODE_LOWER, 0); 
         if (isBuy > Ask)
            return ++signal;
            
         double isSell = Utils.iBands(IndicatorTimeFrame, 20, 2, 0, PRICE_HIGH, MODE_UPPER, 0); 
         if (isSell < Bid)
            return --signal;
         return (signal);   
      }
      
      int TrendIndicator(ENUM_INDICATORS indi) 
      {
          switch(indi)
          {
             case EMAWMAIndicator:
                return GetEMAWMATrend();
             case BandsIndicator:
                return GetBandsTrend();
             case BillWilliamsIndicator:
                return GetBWTrend();
             case ZigZagIndicator:
                return GetZigZagTrend();
             default:
                return 0;
          }
         return 0;
      }
      

};

