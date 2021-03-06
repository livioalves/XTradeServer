//+------------------------------------------------------------------+
//|                                                  TradeExpert.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <XTrade\InputTypes.mqh>
#include <XTrade\ITradeService.mqh>
#include <XTrade\TradeMethods.mqh>
#include <XTrade\TradePanel.mqh>
#include <XTrade\TradeIndicators.mqh>
#include <XTrade\PH\ClassExpert.mqh>
#include <XTrade\Deal.mqh>
#include <XTrade\CommandsController.mqh>


#define SERVICE_HEARTBEAT_TIMEOUT 1000
#define SERVICE_HEARTBEAT_INTERVALS_POSITIONS  5
#define SERVICE_HEARTBEAT_INTERVALS_DEALS  30

// Переменная класса / Class variable
CExpert ExtExpert;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class TradeExpert : CommandsController
  {
protected:
   string            trendString;
   TradeIndicators *signals;
   TradePanel       *panel;
   char              lastChar;
   CIsSession        BUYSession;
   CIsSession        SELLSession;
   /////////////////////
   //PH params
   /////////////////////
   int               DayTheHistogram;
   int               DaysForCalculation;
   int               RangePercent;
   color             InnerRange;
   color             OuterRange;
   color             ControlPoint;
   bool              ShowValue;
   CExpert          *phExpert;   
   //          End PH params   
public:
   TradeMethods     *methods;
   bool              isExpert;
                     TradeExpert()
     {
      BUYSession.Init(StringToTime(GET(BUYBegin)),StringToTime(GET(BUYEnd)));
      SELLSession.Init(StringToTime(GET(SELLBegin)),StringToTime(GET(SELLEnd)));

      methods = NULL;
      signals = NULL;
      panel   = NULL;
      lastChar= 0;
      trendString= "NEUTRAL";
      isExpert=true;

      ////////////PH 
      phExpert=NULL;
      DayTheHistogram=10;          // Дней с гистограммой / Days The Histogram
      DaysForCalculation= 365;          // Дней для расчета(-1 вся) / Days for calculation(-1 all)
      RangePercent       = 70;          // Процент диапазона / Range%
      InnerRange         = Indigo;       // Внутренний диапазон / Inner range
      OuterRange         = Magenta;      // Внешний диапазон / Outer range
      ControlPoint       = Orange;       // Контрольная точка(POC) / Point of Control
      ShowValue          = true;         // Показать значения / Show Value
                                         ////////////PH
     }

                    ~TradeExpert();
   bool              ProcessIndicators(OrderSelection *orders);
   int               InitPH();
   void              OnTimer();
   int               Init();
   void              StartAsService();
   void              DeInit(int reason);
   void              ProcessOrders();
   void              OnTickPendingOrders(OrderSelection *orders);
   void              ProcessStopOrders(OrderSelection *orders);
   string            TransactionDescription(const MqlTradeTransaction &trans);
   string            RequestDescription(const MqlTradeRequest &request);
   string            TradeResultDescription(const MqlTradeResult &result);
   void              ReloadExpert();
   void              UpdateOrders();
   bool              CharIsNumber(uchar sym);
   void              ResetChartPos();
   void              InitChartTheme();

   void   Draw()
   
     {
      if(panel==NULL)
         return;
      if((!Utils.IsTesting()) || Utils.IsVisualMode())
         panel.Draw();
     }
   //+------------------------------------------------------------------+
   bool              TrailByType(Order &order);
   virtual void      OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam);
   string            ReasonToString(int Reason);
   //+------------------------------------------------------------------+
   datetime          TrailingTFNow;
   void OnEachNewBar(Order &order)
   {
   datetime currentBar=iTime(methods.Symbol,methods.Period,0);
   if(TrailingTFNow==currentBar)
      return;
   TrailingTFNow=currentBar;
   methods.TrailEachNewBar(order,methods.Period);
   }
   datetime          SignalTFNow;
   void              CreatePendingOrder(int type);
   
   // from CommandsController
   bool CheckActive();
   void HandleSignal(int id, long lparam, double dparam, string signalStr);
   void ReturnActiveOrders();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::CreatePendingOrder(int type)
{
   int countPending = methods.CountOrdersByRole(PendingLimit, methods.globalOrders) + methods.CountOrdersByRole(PendingStop, methods.globalOrders);
   if (countPending >= 2)
   {
      Utils.Info("Only 2 pending orders allowed!!!");
      return;
   }
   PendingOrder *order = NULL;
   order = new PendingOrder(type, -1, 1);
   order.SetId(methods.GeneratePendingOrderTicket(type));
   Utils.Trade().Orders().Add(order);
   ChartRedraw(methods.chartID);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::OnTickPendingOrders(OrderSelection *orders)
{
   ITradeService *thrift = Utils.Service();
   FOREACH_ORDER(orders)
   {
      if(!order.isPending())
         continue;
      if(order.IsExpired())
      {
         Utils.Info(StringFormat("Pending order expired, Deleted %s", order.ToString()));
         methods.DeletePendingOrder(order);
         return;
      }
      if(order.type==OP_BUY)
        {
         if(!order.isSelected())
           {
            if(order.Role()==PendingLimit)
            {
               double bid = Utils.Bid();
               if (order.openPrice >= bid)
               {
                  SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
                  Signal *manualSignal = new Signal(flag,SIGNAL_MARKET_MANUAL_ORDER,thrift.MagicNumber());
                  manualSignal.Value = order.type;
                  manualSignal.obj["Data"].Add(order.Persistent());
                  
                  manualSignal.SetName("Pending BUYLIMIT");
                  thrift.PostSignalLocally(manualSignal);

                  methods.DeletePendingOrders();
                  ChartRedraw(methods.chartID);
                  return;
               }
            }
            if(order.Role()==PendingStop)
            {
               double ask=Utils.Ask();
               if(order.openPrice<=ask)
                 {
                  SignalFlags flag=thrift.IsMaster()?SignalToCluster:SignalToExpert;
                  Signal *manualSignal=new Signal(flag,SIGNAL_MARKET_MANUAL_ORDER,thrift.MagicNumber());
                  manualSignal.Value = order.type;
                  manualSignal.obj["Data"].Add(order.Persistent());

                  manualSignal.SetName("Pending BUYSTOP");
                  thrift.PostSignalLocally(manualSignal);

                  methods.DeletePendingOrders();
                  ChartRedraw(methods.chartID);
                  return;
                 }
              }
           }
        }
      if(order.type==OP_SELL)
      {
         if(!order.isSelected())
         {
            if(order.Role()==PendingLimit)
            {
               double ask=Utils.Ask();
               if(order.openPrice<=ask)
               {
                  SignalFlags flag=thrift.IsMaster()?SignalToCluster:SignalToExpert;
                  Signal *manualSignal=new Signal(flag,SIGNAL_MARKET_MANUAL_ORDER,thrift.MagicNumber());
                  manualSignal.Value=order.type;
                  manualSignal.obj["Data"].Add(order.Persistent());
                  //order.PersistentTo(manualSignal.obj);
                  
                  manualSignal.SetName("Pending SELLLIMIT");
                  thrift.PostSignalLocally(manualSignal);

                  methods.DeletePendingOrders();
                  ChartRedraw(methods.chartID);
                  return;
               }
            }
            if(order.Role()==PendingStop)
            {
               double bid=Utils.Bid();
               if(order.openPrice>=bid)
               {
                  SignalFlags flag=thrift.IsMaster()?SignalToCluster:SignalToExpert;
                  Signal *manualSignal=new Signal(flag,SIGNAL_MARKET_MANUAL_ORDER,thrift.MagicNumber());
                  manualSignal.Value=order.type;
                  manualSignal.obj["Data"].Add(order.Persistent());
                  manualSignal.SetName("Pending SELLSTOP");
                  thrift.PostSignalLocally(manualSignal);

                  methods.DeletePendingOrders();
                  ChartRedraw(methods.chartID);
                  return;
               }
            }
        }
     }
   }
}
//
// Process stoplosses breakeven and takeprofits
//
void TradeExpert::ProcessStopOrders(OrderSelection *orders)
  {
   FOREACH_ORDER(orders)
     {
      // First close unclosed orders due to errors on Broker servers!!!
      if(!order.isPending())
        {
         double ask = Utils.Ask();
         double bid = Utils.Bid();
         double sl = order.StopLoss(false);
         double tp = order.TakeProfit(false);
         if(sl<=0)
           {
            order.updateSL(false);
            sl=order.StopLoss(false);
           }
         if(tp<=0)
           {
            order.updateTP(false);
            tp=order.TakeProfit(false);
           }
         //double beDistance = methods.Point * GET(CoeffBE) * GET(BrickSize);
         if(order.type==OP_BUY)
           {
            if((bid<=sl) && (sl>0))
              {
               order.MarkToClose();
               Utils.Info(StringFormat("**Stoploss** %s p=%g sl=%g", order.ToString(), order.RealProfit(), order.StopLoss(false)));
              }
            if((ask>=tp) && (tp>0))
              {
               order.MarkToClose();
               Utils.Info(StringFormat("**TakeProfit** %s p=%g tp=%g", order.ToString(), order.RealProfit(), order.TakeProfit(false)));
              }
/*
            if ( beDistance > 0 )
            {
               // Process BE
               if ( ((bid - order.openPrice ) > beDistance) 
                    && (Utils.OrderProfit() > 0) )
               {  
                  double Spread = MathMax(Utils.Spread() * methods.Point, ask - bid);
                  double beSL = NormalizeDouble(order.openPrice + Spread, _Digits);
                  if ( (sl < beSL) && (Spread < beDistance))
                  {
                     order.setStopLoss( beSL );
                     methods.UpdateStopLossesTakeProfits(true);
                     Utils.Info(StringFormat("**BreakEven** %s BE=%g", order.ToString(), order.StopLoss(false)));
                  }
               }
            }
*/
            continue;
           }
         if(order.type==OP_SELL)
           {
            if((ask>=sl) && (sl>0))
              {
               order.MarkToClose();
               Utils.Info(StringFormat("**Stoploss** %s p=%g sl=%g", order.ToString(), order.RealProfit(), order.StopLoss(false)));
              }
            if((bid<=tp) && (tp>0))
              {
               order.MarkToClose();
               Utils.Info(StringFormat("**TakeProfit** %s p=%g tp=%g", order.ToString(), order.RealProfit(), order.TakeProfit(false)));
              }
/*
            if (beDistance > 0)
            {
               // Process BE
               if ( (( order.openPrice - ask ) > beDistance)
                   && (Utils.OrderProfit() > 0) )
               {  
                  double Spread = MathMax(Utils.Spread() * methods.Point, ask - bid);
                  double beSL = NormalizeDouble(order.openPrice - Spread, _Digits);
                  if ( ( sl > beSL) && (Spread < beDistance))
                  {
                     order.setStopLoss( beSL );
                     methods.UpdateStopLossesTakeProfits(true);
                     Utils.Info(StringFormat("**BreakEven** %s BE=%g", order.ToString(), order.StopLoss(false)));
                  }
               }
            }
*/
            continue;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeExpert::CharIsNumber(uchar sym)
{
   if((sym>'0') && (sym<='9'))
      return true;
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::OnEvent(const int id,   // Event identifier  
                          const long& lparam,     // Event parameter of long type
                          const double& dparam,   // Event parameter of double type
                          const string& sparam)   // Event parameter of string type
  {
//--- the key has been pressed
   if(id==CHARTEVENT_KEYDOWN)
     {
      if((lparam=='O') || (lparam=='o'))
        {
         lastChar='o';
         return;
        }

      if((lparam=='P') || (lparam=='p'))
        {
         lastChar='p';
         return;
        }

      if(lastChar=='o')
        {
         if(GET(AllowMarketOrders))
           {
            if((lparam=='s') || (lparam=='S'))
              {
               lastChar=0;
               ITradeService* thrift= Utils.Service();
               Signal* manualSignal = NULL;
               SignalFlags flag=thrift.IsMaster()?SignalToCluster:SignalToExpert;
               manualSignal=new Signal(flag,SIGNAL_MARKET_MANUAL_ORDER,thrift.MagicNumber());
               manualSignal.Value=OP_SELL;

               Order *order=Utils.Trade().InitManualOrder(manualSignal.Value);
               manualSignal.obj["Data"] = order.Persistent();

               thrift.PostSignal(manualSignal);
               return;
              }

            if((lparam=='b') || (lparam=='B'))
            {
               lastChar=0;
               ITradeService *thrift=Utils.Service();
               SignalFlags flag=thrift.IsMaster()?SignalToCluster:SignalToExpert;
               Signal *manualSignal=new Signal(flag,SIGNAL_MARKET_MANUAL_ORDER,thrift.MagicNumber());
               manualSignal.Value=OP_BUY;
               
               Order *order = Utils.Trade().InitManualOrder(manualSignal.Value);
               manualSignal.obj["Data"] = order.Persistent();
               
               thrift.PostSignal(manualSignal);
               return;
            }

           }
         else
           {
            Utils.Info("Market orders are not allowed for "+Symbol());
            return;
           }
        }

      if(lastChar=='p')
        {
         if(lparam=='s' || lparam=='S')
           {
            lastChar=0;
            CreatePendingOrder(OP_SELL);
            return;
           }

         if(lparam=='b' || lparam=='B')
           {
            lastChar=0;
            CreatePendingOrder(OP_BUY);
            return;
           }
        }

      if(lparam==82) // r key
        {
         ReloadExpert();
         return;
        }

      switch(int(lparam))
        {
         case KEY_NUMLOCK_UP:
         case KEY_UP:
            FOREACH_ORDER(methods.globalOrders)
              {
               if(order.isPending())
                 {
                  if(order.isSelected())
                    {
                     order.ShiftUp();
                    }
                 }
              }
            return;
            break;
         case KEY_NUMLOCK_DOWN:
         case KEY_DOWN:
            FOREACH_ORDER(methods.globalOrders)
              {
               if(order.isPending())
                 {
                  if(order.isSelected())
                    {
                     order.ShiftDown();
                    }
                 }
              }
            return;
            break;
         case KEY_NUMLOCK_RIGHT:
         case KEY_RIGHT:
            break;
         case KEY_NUMLOCK_LEFT:
         case KEY_LEFT:
            break;

         default:
            ;
        }

      if((lparam=='d') || (lparam=='D'))
        {
         FOREACH_ORDER(methods.globalOrders)
           {
            if(order.isPending())
              {
               if(order.isSelected())
                 {
                  order.Delete();
                  methods.globalOrders.DeleteCurrent();
                 }
              }
           }
         ChartRedraw(methods.chartID);
         return;
        }

      if((lparam=='u') || (lparam=='U'))
        {
         methods.UpdateStopLossesTakeProfits(true);
         return;
        }
        
      if((lparam=='q') || (lparam=='Q'))
      {
         this.ResetChartPos();
         return;
      }
  
      if(CharIsNumber((uchar)lparam))
        {
         methods.HandleNumbers((uchar)lparam);
         return;
        }
     }

//if(id>=CHARTEVENT_CUSTOM && id<=CHARTEVENT_CUSTOM_LAST)
//  {
//   this.controller.HandleSignal(id,lparam,dparam,sparam);
//   return;
//  }

   if(panel!=NULL)
      panel.OnEvent(id,lparam,dparam,sparam);

   if(phExpert!=NULL)
      phExpert.OnEvent(id,lparam,dparam,sparam);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::ReloadExpert()
{
   string templateName=Utils.Service().Name()+".tpl";
   ChartApplyTemplate(0,templateName);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::DeInit(int Reason)
{
   ITradeService *thrift=Utils.Service();
   if((Reason!=REASON_PARAMETERS) || (Reason!=REASON_TEMPLATE))
     {
      //SaveGlobalProperties();
      if((methods!=NULL) && thrift.IsEA)
         methods.SaveOrders();
     }

   datetime now=TimeCurrent();
   if(thrift.IsEA)
      Utils.Info(StringFormat("Expert <%s> closed with reason %s At %s.",Utils.Symbol,ReasonToString(Reason),TimeToString(now)));
   else
      Utils.Info(StringFormat("Terminal <%d> Service Stopped at %s.",Utils.AccountNumber(),TimeToString(now)));

   DELETE_PTR(panel)

   if(phExpert!=NULL)
     {
      phExpert.Deinit(Reason);
      DELETE_PTR(phExpert)
     }

   DELETE_PTR(signals)

   DELETE_PTR(methods)

   if(thrift!=NULL)
      thrift.DeInit(Reason);

   DELETE_PTR(Utils);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
TradeExpert::~TradeExpert()
{

}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TradeExpert::InitPH()
{
//---
// Проверяем синхронизацию инструмента перед началом расчетов / We check tool synchronisation before the beginning of accounts
   int err=0;
   while(!(bool)SeriesInfoInteger(Symbol(),0,SERIES_SYNCHRONIZED) && err<AMOUNT_OF_ATTEMPTS)
     {
      Sleep(500);
      err++;
     }
// Инициализация класса CExpert / Initialization of class CExpert
   phExpert=new CExpert();
   phExpert.RangePercent=RangePercent;
   phExpert.InnerRange=InnerRange;
   phExpert.OuterRange=OuterRange;
   phExpert.ControlPoint=ControlPoint;
   phExpert.ShowValue=ShowValue;
   phExpert.DaysForCalculation=DaysForCalculation;
   phExpert.DayTheHistogram=DayTheHistogram;
   if (GET(EnableRenko))
      phExpert.ShowHistogram = false;
   phExpert.Init();
   return(0);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::OnTimer()
{
   if ( phExpert != NULL )
   {
      phExpert.OnTimer();
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TradeExpert::Init()
{
// Utils.ObjDeleteAll();
   ITradeService *thrift = Utils.Service();

   isExpert=true;
   if(!thrift.Init(isExpert))
      return INIT_FAILED;
      
   thrift.SetController(GetPointer(this));

   if((Digits()==3) || (Digits()==5))
   {
      actualSlippage = GET(Slippage)*10;
   }
   

   methods = new TradeMethods();
   
   InitChartTheme();

   Utils.SetTrade(methods);
   if(GET(PanelSize)!=PanelNone)
      panel= new TradePanel(GetPointer(this));
   signals = new TradeIndicators(methods,panel);
   methods.SetSignalsProcessor(signals);
   
   

   methods.Init();

   string initMessage=StringFormat("OnInit Expert On <%s>",Utils.Symbol);
   Utils.Info(initMessage);

// TestOrders();

   if ( panel != NULL )
      panel.Init();

// Init Price Histogramm      
   if (GET(EnableHistogram))
      InitPH();

   methods.LoadOrders();

   methods.UpdateStopLossesTakeProfits(true);

   ResetChartPos();
   // ChartNavigate(methods.ChartId(),CHART_END,0);
   // Utils.Service().DealsHistory(1);
   return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::StartAsService()
  {
   ITradeService *thrift=Utils.Service();

   isExpert=false;
   if(!thrift.Init(isExpert))
      return;

   methods=new TradeMethods();
   Utils.SetTrade(methods);
   panel=NULL;
   signals=NULL;// new TradeIndicators(methods, panel);
   methods.SetSignalsProcessor(signals);

   methods.Init();

   datetime now=TimeCurrent();
   string initMessage=StringFormat("Starting Service at %s on Account:%d",TimeToString(now),Utils.GetAccountNumer());
   Utils.Info(initMessage);

   int deals_i=SERVICE_HEARTBEAT_INTERVALS_DEALS;
   int positions_i=SERVICE_HEARTBEAT_INTERVALS_POSITIONS;
   while(!IsStopped())
     {
      
      Signal *signal=Utils.Service().ListenSignal(SignalToServer,Utils.AccountNumber());
      if(signal!=NULL) 
      {
         ushort event_id=(ushort)(signal.type);  // +CHARTEVENT_CUSTOM);
         if(event_id!=0)
         {
            HandleSignal(event_id,signal.ObjectId, signal.Value,signal.Serialize());
         }
         DELETE_PTR(signal);
      } 
      Sleep(SERVICE_HEARTBEAT_TIMEOUT);
      if(positions_i==0)
        {
         positions_i=SERVICE_HEARTBEAT_INTERVALS_POSITIONS;
         ReturnActiveOrders();
        }
      else
         positions_i--;
      if(deals_i==0)
        {
         deals_i=SERVICE_HEARTBEAT_INTERVALS_DEALS;
         Utils.Service().DealsHistory(1);
        }
      else
         deals_i--;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::UpdateOrders()
  {
   if(panel==NULL)
      return;
   if(!Utils.IsTesting() || Utils.IsVisualMode())
      panel.Draw();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeExpert::ProcessOrders()
  {
   Utils.RefreshRates();
   if(phExpert!=NULL)
      phExpert.OnTick();
   Utils.Service().ProcessSignals();
   OrderSelection *orders=methods.GetOpenOrders();
   OnTickPendingOrders(orders);
   ProcessStopOrders(orders);
   double CheckPrice= 0;
   double LossLevel = 0;
   double orderProfit=0;
   int i=0;

   int pendingDeleteCount=methods.CountOrdersByRole(ShouldBeClosed,orders);
   if(pendingDeleteCount>0)
     {
      FOREACH_ORDER(orders)
        {
         // First close unclosed orders due to errors on Broker servers!!!
         if(order.Role()==ShouldBeClosed)
           {
            if(methods.CloseOrder(order))
              {
               orders.DeleteCurrent();
              }
           }
        }
      orders.Sort();
     }

   if(panel!=NULL)
   {
      panel.OrdersString = StringFormat("Default(%s) TotalProfit(%g) DailyProfit(%g) MaxGain(%g)",
            EnumToString((ENUM_TRAILING)GET(TrailingType)), methods.GetProfit(orders),
            Utils.GetDailyProfit(), Utils.GetMaxGain());
   }

   ProcessIndicators(orders);

   FOREACH_ORDER(orders)
     {
      if(TrailByType(order))
         return;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeExpert::ProcessIndicators(OrderSelection *orders)
{
   datetime currentBar = iTime(methods.Symbol,methods.Period,0);
   if (SignalTFNow != currentBar) 
   {
      SignalTFNow=currentBar;
      if(GET(SignalIndicator)==NoIndicator) // No signals - no auto trading
         return false;
      //signals.ProcessFilter();
      signals.RefreshIndicators();
      int countBUY=methods.CountOrdersByType(OP_BUY,orders);
      int countSELL=methods.CountOrdersByType(OP_SELL,orders);
      if(GET(AllowBUY) && BUYSession.IsSession() && (countBUY==0))
      {
         signals.ProcessSignal();
      }
      else
      if(GET(AllowSELL) && SELLSession.IsSession() && (countSELL==0))
      {
         signals.ProcessSignal();
      }
   }
   return true;
}
//+------------------------------------------------------------------+
bool TradeExpert::TrailByType(Order &order)
  {
   if((GET(TrailingType)==TrailingManual) || (order.Role()!=RegularTrail))
      return false;
   ENUM_TRAILING trailing = (ENUM_TRAILING)GET(TrailingType);
   if(order.TrailingType != TrailingDefault)
      trailing=order.TrailingType;
   switch(trailing)
     {
      case TrailingManual:
      case TrailingDefault:
         // Just skip trailing
         return false;
      case TrailingStairs:
        {
         double startDistance=GET(CoeffBE) *(double)GET(BrickSize);
         methods.TrailingStairs(order,(int)startDistance,(int)GET(BrickSize));
         return false;
        }
      case TrailingByFractals:
         methods.TrailingByFractals(order,methods.Period,(int)GET(NumBarsToAnalyze),(int)GET(TrailingIndent),false);  // good for USDCHF USDJPY and by default
         return false;
      case TrailingByShadows:
         methods.TrailingByShadows(order,methods.Period,(int)GET(NumBarsToAnalyze),(int)GET(TrailingIndent),false);
         return false;
      case TrailingByATR:
         methods.TrailingByATR(order,methods.Period,1,GET(CoeffSL),GET(CoeffTP),false);
         return false;
         return false;
      case TrailingFiftyFifty:
         methods.TrailingFiftyFifty(order,methods.Period,0.5,false);   // Good for EURUSD / EURAUD and for FlatTrend
         return false;
         return false;
      case TrailingByPriceChannel:
        {
         methods.TrailingByPriceChannel(order,(int)GET(NumBarsToAnalyze),(int)GET(TrailingIndent)); //actualStopLossLevel NumBarsFractals >= 10, TrailingIndent = 10
         return false;
        }
      case TrailingFilter:
        {
         signals.FI.Trail(order,(int)GET(TrailingIndent));
         return false;
        }
      case TrailingSignal:
        {
         signals.SI.Trail(order,(int)GET(TrailingIndent));
         return false;
        }
      //case TrailingIchimoku:
      //{
      //signals.TMAM15.Trail(order, TrailingIndent);
      //return true;
      //}
      case TrailEachNewBar:
         OnEachNewBar(order);
         return false;
         return false;

     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TradeExpert::ReasonToString(int Reason)
  {
   switch(Reason)
     {
      case 0: //0
         return "0 <REASON_PROGRAM> - Expert Advisor terminated its operation by calling the _ExpertRemove()_ function";
      case 1: //1
         return "1 <REASON_REMOVE> Program has been deleted from the chart";
      case 2: // 2
         return "2 <REASON_RECOMPILE> Program has been recompiled";
      case 3: //3
         return "3 <REASON_CHARTCHANGE> Symbol or chart period has been changed";
      case 4:
         return "4 <REASON_CHARTCLOSE> Chart has been closed";
      case 5:
         return "5 <REASON_PARAMETERS> Input parameters have been changed by a user";
      case 6:
         return "6 <REASON_ACCOUNT> Another account has been activated or reconnection to the trade server has occurred due to changes in the account settings";
      case 7:
         return "7 <REASON_TEMPLATE> A new template has been applied";
      case 8:
         return "8 <REASON_INITFAILED> This value means that _OnInit()_ handler has returned a nonzero value";
      case 9:
         return "9 <REASON_CLOSE> Terminal has been closed";
     }
   return StringFormat("Unknown reason: %s", Reason);
  }
//+------------------------------------------------------------------+ 
//| Returns transaction textual description                          | 
//+------------------------------------------------------------------+ 
string TradeExpert::TransactionDescription(const MqlTradeTransaction &trans)
  {
//---  
   string desc=EnumToString(trans.type)+": ";
   desc+="Symbol: "+trans.symbol+", ";
   desc+="Deal ticket: "+(string)trans.deal+", ";
   desc+="Deal type: "+EnumToString(trans.deal_type)+", ";
   desc+="Order ticket: "+(string)trans.order+", ";
   desc+="Order type: "+EnumToString(trans.order_type)+", ";
   desc+="Order state: "+EnumToString(trans.order_state)+", ";
   desc+="Order time type: "+EnumToString(trans.time_type)+", ";
   desc+="Order expiration: "+TimeToString(trans.time_expiration)+", ";
   desc+="Price: "+StringFormat("%G",trans.price)+", ";
   desc+="Price trigger: "+StringFormat("%G",trans.price_trigger)+", ";
   desc+="Stop Loss: "+StringFormat("%G",trans.price_sl)+", ";
   desc+="Take Profit: "+StringFormat("%G",trans.price_tp)+", ";
   desc+="Volume: "+StringFormat("%G",trans.volume)+", ";
   desc+="Position: "+(string)trans.position+", ";
   desc+="Position by: "+(string)trans.position_by+", ";
//--- return the obtained string 
   return desc;
  }
//+------------------------------------------------------------------+ 
//| Returns the trade request textual description                    | 
//+------------------------------------------------------------------+ 
string TradeExpert::RequestDescription(const MqlTradeRequest &request)
  {
//--- 
   string desc=EnumToString(request.action)+": ";
   desc+="Sym: "+request.symbol+", ";
   desc+="Magic: "+StringFormat("%d",request.magic)+", ";
   desc+="ticket: "+(string)request.order+", ";
   desc+="type: "+EnumToString(request.type)+", ";
   desc+="filling: "+EnumToString(request.type_filling)+", ";
   desc+="time type: "+EnumToString(request.type_time)+", ";
   desc+="expiration: "+TimeToString(request.expiration)+", ";
   desc+="Price: "+StringFormat("%G",request.price)+", ";
   desc+="DeviationPt: "+StringFormat("%G",request.deviation)+", ";
   desc+="SL: "+StringFormat("%G",request.sl)+", ";
   desc+="TP: "+StringFormat("%G",request.tp)+", ";
   desc+="StopLimit: "+StringFormat("%G",request.stoplimit)+", ";
   desc+="Volume: "+StringFormat("%G",request.volume)+", ";
   desc+="Comment: "+request.comment+".";
//--- return the obtained string 
   return desc;
  }
//+------------------------------------------------------------------+ 
//| Returns the textual description of the request handling result   | 
//+------------------------------------------------------------------+ 
string TradeExpert::TradeResultDescription(const MqlTradeResult &result)
  {
//--- 
   string desc="Retcode "+(string)result.retcode+", ";
   desc+="Request ID: "+StringFormat("%d",result.request_id)+", ";
   desc+="Order ticket: "+(string)result.order+", ";
   desc+="Deal ticket: "+(string)result.deal+".";
//desc+="Volume: "+StringFormat("%G",result.volume)+"\r\n"; 
//desc+="Price: "+StringFormat("%G",result.price)+"\r\n"; 
//desc+="Ask: "+StringFormat("%G",result.ask)+"\r\n"; 
//desc+="Bid: "+StringFormat("%G",result.bid)+"\r\n"; 
//desc+="Comment: "+result.comment+"\r\n"; 
//--- return the obtained string 
   return desc;
  }

/*

void TestOrders()
{
    Order* arr[];
    ArrayResize(arr, MaxOpenedTrades);
    int k = 0;
    for(k = 0; k<MaxOpenedTrades;k++)
    {
       arr[k] = new Order(k);
       methods.globalOrders.Add(arr[k]);
    }

    int i = 0;
    FOREACH_ORDER(methods.globalOrders)
    {
       if (i%2==0)
          methods.globalOrders.DeleteCurrent();
       i++;   
    }
    methods.globalOrders.Sort();
    
    FOREACH_ORDER(methods.globalOrders)
    {
       order.Print();
    }
    
    i = methods.globalOrders.Total();
    k = 100;
    while (i++ < MaxOpenedTrades)
    {
        Order* or = new Order(k++);
        methods.globalOrders.Add(or);
    }
    
    methods.globalOrders.DeleteByTicket(1);
    methods.globalOrders.DeleteByTicket(k-1);
    
    FOREACH_ORDER(methods.globalOrders)
    {
       order.Print();
    }
    methods.globalOrders.Clear();
}
*/
//+------------------------------------------------------------------+

bool TradeExpert::CheckActive() 
{
   ITradeService *thrift=Utils.Service();
   return thrift.CheckActive();
}

void TradeExpert::HandleSignal(int id, long lparam, double dparam, string signalStr)
{
   ITradeService *thrift = Utils.Service();
   // Utils.Info("Received event from server: " + IntegerToString(lparam) + ": " + DoubleToString(dparam));
   SignalType signalId = (SignalType)(id);// - CHARTEVENT_CUSTOM);
   switch (signalId) {
      case SIGNAL_CHECK_BALANCE:
      {
          Signal* retSignal = new Signal(SignalToServer, SIGNAL_CHECK_BALANCE, thrift.MagicNumber());
          CJAVal obj;
          obj["Balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
          obj["Equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
          obj["Account"] = (long)Utils.AccountNumber();
          retSignal.obj["Data"].Add(obj);
          thrift.PostSignal(retSignal);        
      } break;
      case SIGNAL_INIT_EXPERT:
         
      break;
      case SIGNAL_UPDATE_EXPERT:
          ReloadExpert();
      break;
      case SIGNAL_MARKET_MANUAL_ORDER:
      {
         // int len = StringLen(signalStr);
         Signal signal(signalStr);
         
         //if (thrift.IsMaster() && (signal.flags == SignalToCluster))
         //{
         //   Signal* clusterSignal = new Signal(SignalToCluster, signalId, thrift.MagicNumber());
         //   clusterSignal.Value = signal.Value;
         //   thrift.PostSignal(clusterSignal);
         //} else {
            string fromJson = signal.obj["Data"].Serialize();
            if ( StringLen(fromJson) > 0 )
               fromJson = StringSubstr(fromJson, 1, StringLen(fromJson) - 2);
            Order* order = new Order(fromJson);
            order.comment = signal.GetName();
            
            methods.OpenOrder(order);
         //}
      } break;
      case SIGNAL_MARKET_EXPERT_ORDER: 
      {
         Signal signal(signalStr);
         if (thrift.IsMaster())
         {
            Signal* clusterSignal = new Signal(SignalToCluster, signalId, thrift.MagicNumber());
            clusterSignal.Value = signal.Value;
            thrift.PostSignal(clusterSignal);
         } else 
         {
            Order* order = methods.InitExpertOrder(signal.Value);
            order.comment = signal.GetName();
            methods.OpenOrder(order);
         }
      } break;
      case SIGNAL_MARKET_FROMPENDING_ORDER: {
         //Signal signal(signalStr);
         //if ( signal.Value == 0 ) 
         //   expert.OpenOrder(expert.InitFromPending(OP_BUY));
         //else 
         //   expert.OpenOrder(expert.InitFromPending(OP_SELL));
      } break;
      case SIGNAL_ACTIVE_ORDERS:
         ReturnActiveOrders();     
      break;
      case SIGNAL_CLOSE_POSITION:
      {
         Signal* signal = new Signal(signalStr);
         
         Utils.Info(StringFormat("**IsExpert(%d) Trying Manual Close Order**: %d", isExpert, signal.Value));
         Order* order = NULL;
         //if (signal.Value < 0)
         //{
         //   signal.flags = SignalToExpert;
         //   string strmagic = signal.obj["Data"].Serialize();
         //   signal.ObjectId = StringToInteger(strmagic);
         //   this.thrift.PostSignal(signal);
         //   return;
         //}
         if (isExpert)
         {
             OrderSelection* orders = Utils.Trade().Orders();
             order = orders.SearchOrder(signal.Value);
         }
         else {
            order = new Order(signal.Value);
            order.Select();
            order.symbol = Utils.OrderSymbol();
            methods.Orders().Fill(order);
         }
         if (order != NULL) 
         {
            Utils.Info(StringFormat("**Manual Close Order**: %s p=%g", order.ToString(), order.RealProfit()));
            if (order.isPending())
            {
               methods.DeletePendingOrder(order);
            } else 
            {
               methods.CloseOrder(order);
            }
         }
         DELETE_PTR(signal);
      } break;
      case SIGNAL_DEALS_HISTORY: {
         Utils.Service().DealsHistory((int)dparam);
      } break;
   }
}

void TradeExpert::ReturnActiveOrders() 
{
   ITradeService *thrift=Utils.Service();

   //if (this.expert.isExpert) 
   //    return; // Run this code only in service mode
   
   Signal* retSignal = new Signal(SignalToServer, SIGNAL_ACTIVE_ORDERS, thrift.MagicNumber());
   retSignal.Value = (int)Utils.GetAccountNumer();
   OrderSelection* orders = Utils.Trade().Orders();
   FOREACH_ORDER(orders)
   {
       if (order.isPending())
          retSignal.obj["Data"].Add(order.Persistent());
   }   
   for (int i = Utils.OrdersTotal() - 1; i >= 0; i-- )
   {     
      if (Utils.SelectOrderByPos(i))
      {
         long Ticket = Utils.OrderTicket();
         Order* oldOrder = orders.SearchOrder(Ticket);
         if (oldOrder != NULL)
         {
            orders.Fill(oldOrder);
            retSignal.obj["Data"].Add(oldOrder.Persistent());
         } else 
         {
            //long Magic = Utils.OrderMagicNumber();
            //if ( Magic <= 0 ) // for external orders only
            //{
               Order* newOrder = new Order(Ticket);
               orders.Fill(newOrder);
               retSignal.obj["Data"].Add(newOrder.Persistent());
               DELETE_PTR(newOrder);
            //}
         }
       }
   }
   thrift.PostSignal(retSignal);
   // Utils.Info("Update Active Positions");
}

void TradeExpert::ResetChartPos() 
{
   ChartSetInteger(methods.chartID,CHART_AUTOSCROLL,false);
   ChartSetInteger(methods.chartID,CHART_SHIFT,true); 
   ChartNavigate(methods.chartID, CHART_END, 33);
}

void TradeExpert::InitChartTheme() 
{
   if (methods == NULL)
      return;
   if (GET(EnableRenko)) {
      // ChartSetInteger(methods.chartID,CHART_MODE,CHART_CANDLES); 
   
   } else {
   
      ChartSetInteger(methods.chartID,CHART_MODE,CHART_BARS); 
      //--- set the display mode for tick volumes 
      ChartSetInteger(methods.chartID,CHART_SHOW_VOLUMES,CHART_VOLUME_TICK); 
      ChartSetInteger(methods.chartID,CHART_COLOR_BACKGROUND,clrBlack); 
      ChartSetInteger(methods.chartID,CHART_COLOR_FOREGROUND,clrWhite); 
      ChartSetInteger(methods.chartID,CHART_COLOR_VOLUME,clrGreen); 
      ChartSetInteger(methods.chartID,CHART_COLOR_CHART_UP,clrLimeGreen); 
      ChartSetInteger(methods.chartID,CHART_COLOR_CANDLE_BULL,clrLimeGreen); 
      
      ChartSetInteger(methods.chartID,CHART_COLOR_CHART_DOWN,clrRed); 
      ChartSetInteger(methods.chartID,CHART_COLOR_CANDLE_BEAR,clrRed); 
      ChartSetInteger(methods.chartID,CHART_COLOR_CHART_LINE,clrWhite); 
      
      
      
   }
   
}

