//+------------------------------------------------------------------+
//|                                                 TradeExpert.mqh |
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
#include <XTrade\CommandsController.mqh>

class CommandsController;

class TradeExpert 
{
protected:
   string trendString;
   TradeIndicators* signals;
   TradePanel*   panel;
   char lastChar;
   CIsSession BUYSession;
   CIsSession SELLSession;
   CommandsController* controller;
public:
   TradeMethods* methods;
   TradeExpert()
     
   {
      BUYSession.Init(StringToTime(GET(BUYBegin)), StringToTime(GET(BUYEnd)));
      SELLSession.Init(StringToTime(GET(SELLBegin)), StringToTime(GET(SELLEnd)));
   
      methods = NULL;
      signals = NULL;
      panel   = NULL;
      lastChar = 0;
      trendString = "NEUTRAL";
      controller = new CommandsController(GetPointer(this));
   }
   
   ~TradeExpert();

   bool ProcessIndicators(OrderSelection* orders);
   int  Init();
   void DeInit(int reason);
   void ProcessOrders();
   void OnTickPendingOrders(OrderSelection* orders);
   void ProcessStopOrders(OrderSelection* orders);
   string TransactionDescription(const MqlTradeTransaction &trans);
   string RequestDescription(const MqlTradeRequest &request);
   string TradeResultDescription(const MqlTradeResult &result);
   void ReloadExpert();
   
   void UpdateOrders();
   
   void Draw()
   {
      if (panel == NULL)
         return;
      if ( (!Utils.IsTesting()) || Utils.IsVisualMode()) 
         panel.Draw();
   }

   //+------------------------------------------------------------------+
   bool TrailByType(Order& order);
   virtual void      OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam);
   string ReasonToString(int Reason);
   
   //+------------------------------------------------------------------+
   datetime TrailingTFNow;
   void OnEachNewBar(Order& order)
   {
      datetime currentBar = iTime(methods.Symbol, methods.Period, 0);
      if ( TrailingTFNow ==  currentBar )
         return;
      TrailingTFNow = currentBar;
      methods.TrailEachNewBar(order, methods.Period);
   }
   datetime SignalTFNow;
   //Order* InitManualOrder(int type);
   //Order* InitExpertOrder(int type);   
   //Order* InitFromPending(PendingOrder* pend);   
   void   CreatePendingOrder(int type);
   //Order* OpenOrder(Order* order);
};

// void TradeExpert::CreatePendingOrder(int type)

void TradeExpert::CreatePendingOrder(int type)
{
   int countPending = methods.CountOrdersByRole(PendingLimit, methods.globalOrders)
                      + methods.CountOrdersByRole(PendingStop, methods.globalOrders);
   if (countPending >= 2)
   {
       Utils.Info("Only 2 pending orders allowed!!!");
       return;
   }
   PendingOrder* order = NULL;
   if (type == OP_BUY)
   {
       order = new PendingOrder(OP_BUY);
       order.SetId(methods.GeneratePendingOrderTicket(type));
   }
   else if (type == OP_SELL) 
        {
             order = new PendingOrder(OP_SELL);
             order.SetId(methods.GeneratePendingOrderTicket(type));
        }
   Utils.Trade().Orders().Add(order);
   ChartRedraw(methods.chartID); 
}

void TradeExpert::OnTickPendingOrders(OrderSelection* orders)
{
   ITradeService* thrift = Utils.Service();

   FOREACH_ORDER(orders)
   {
      if (!order.isPending())
         continue;
         
      if (order.IsExpired()) {
         Utils.Info(StringFormat("Pending order expired, Deleted %s", order.ToString()));
         methods.DeletePendingOrder(order);
         return;
      }
      
      if (order.type == OP_BUY)
      {
         if (!order.isSelected())
         {
            if (order.Role() == PendingLimit) 
            {
               double bid = Utils.Bid();
               if (order.openPrice >= bid)
               {
                   SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
                   Signal* manualSignal = new Signal(flag, SIGNAL_MARKET_MANUAL_ORDER, thrift.MagicNumber());
                   manualSignal.Value = order.type;
                   manualSignal.SetName("Pending BUYLIMIT");
                   thrift.PostSignal(manualSignal);

                   // Order* marketOrder = OpenOrder(InitFromPending(order));
                   // Order::OrderMessage(marketOrder, "Pending BUYLIMIT");
                   methods.DeletePendingOrders();
                   ChartRedraw(methods.chartID);
                   return;
               }
            }
            if (order.Role() == PendingStop) 
            {
               double ask = Utils.Ask();
               if (order.openPrice <= ask)
               {
                   SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
                   Signal* manualSignal = new Signal(flag, SIGNAL_MARKET_MANUAL_ORDER, thrift.MagicNumber());
                   manualSignal.Value = order.type;
                   manualSignal.SetName("Pending BUYSTOP");
                   thrift.PostSignal(manualSignal);

                   //Order* marketOrder = OpenOrder(InitFromPending(order));
                   //Order::OrderMessage(order, "Pending BUYSTOP");
                   methods.DeletePendingOrders();
                   ChartRedraw(methods.chartID);
                   return;
               }
            }
         }
      }
      if (order.type == OP_SELL)
      {
         if (!order.isSelected())
         {
            if (order.Role() == PendingLimit) 
            {
               double ask = Utils.Ask();
               if (order.openPrice <= ask)
               {
                   SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
                   Signal* manualSignal = new Signal(flag, SIGNAL_MARKET_MANUAL_ORDER, thrift.MagicNumber());
                   manualSignal.Value = order.type;
                   manualSignal.SetName("Pending SELLLIMIT");
                   thrift.PostSignal(manualSignal);

                   //Order* marketOrder = OpenOrder(InitFromPending(order));
                   //Order::OrderMessage(marketOrder, "Pending SELLLIMIT");
                   methods.DeletePendingOrders();
                   ChartRedraw(methods.chartID);
                   return;
               }     
            }
            if (order.Role() == PendingStop) 
            {
               double bid = Utils.Bid();
               if (order.openPrice >= bid)
               {
                   SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
                   Signal* manualSignal = new Signal(flag, SIGNAL_MARKET_MANUAL_ORDER, thrift.MagicNumber());
                   manualSignal.Value = order.type;
                   manualSignal.SetName("Pending SELLSTOP");
                   thrift.PostSignal(manualSignal);

                   //Order* marketOrder = OpenOrder(InitFromPending(order));
                   //Order::OrderMessage(marketOrder, "Pending SELLSTOP");
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
void TradeExpert::ProcessStopOrders(OrderSelection* orders)
{
   FOREACH_ORDER(orders)
   {
      // First close unclosed orders due to errors on Broker servers!!!
      if (!order.isPending())
      {
         double ask = Utils.Ask();
         double bid = Utils.Bid();
         double sl = order.StopLoss(false);
         double tp = order.TakeProfit(false);
         if (sl <= 0)
         {
             order.updateSL(false);
             sl = order.StopLoss(false);
         }
         if (tp <= 0)
         {
             order.updateTP(false);
             tp = order.TakeProfit(false);
         }
         double beDistance = methods.Point * GET(CoeffBE) * GET(BrickSize);
         if (order.type == OP_BUY) 
         {
            if ( (bid <= sl) && (sl > 0))
            {
               order.MarkToClose();
               Utils.Info(StringFormat("**Stoploss** %s p=%g sl=%g", order.ToString(), order.RealProfit(), order.StopLoss(false)));
            }
            if ( (ask >= tp) && (tp > 0) )
            {
               order.MarkToClose();
               Utils.Info(StringFormat("**TakeProfit** %s p=%g tp=%g", order.ToString(), order.RealProfit(), order.TakeProfit(false)));
            }
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
            continue;
         }
         if (order.type == OP_SELL) 
         {
            if ( (ask >= sl) && (sl > 0))
            {
               order.MarkToClose();
               Utils.Info(StringFormat("**Stoploss** %s p=%g sl=%g", order.ToString(), order.RealProfit(), order.StopLoss(false)));
            }
            if ( (bid <= tp) && (tp > 0) )
            {
                  order.MarkToClose();
                  Utils.Info(StringFormat("**TakeProfit** %s p=%g tp=%g", order.ToString(), order.RealProfit(), order.TakeProfit(false)));
            }
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
            continue;
         }
      }
   }
}

void TradeExpert::OnEvent(const int id, // Event identifier  
                  const long& lparam,    // Event parameter of long type
                  const double& dparam,  // Event parameter of double type
                  const string& sparam)  // Event parameter of string type
{

  //--- the key has been pressed
  if( id == CHARTEVENT_KEYDOWN )
  {
         
      if (lparam=='O' || lparam=='o')
         lastChar = 'o';
         
      if (lparam=='P' || lparam=='p')
         lastChar = 'p';

      if (lastChar=='o')
      {
         if (lparam=='s' || lparam=='S')
         {
            lastChar = 0;
            ITradeService* thrift = Utils.Service();
            Signal* manualSignal = NULL;
            SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
            manualSignal = new Signal(flag, SIGNAL_MARKET_MANUAL_ORDER, thrift.MagicNumber());
            manualSignal.Value = OP_SELL;
            // Order* order = this.InitManualOrder(manualSignal.Value);
            // manualSignal.obj["Data"] = order.Persistent();
            thrift.PostSignal(manualSignal);
            return;
         }

         if (lparam=='b' || lparam=='B')
         {
            lastChar = 0;
            ITradeService* thrift = Utils.Service();
            SignalFlags flag = thrift.IsMaster()?SignalToCluster:SignalToExpert;
            Signal* manualSignal = new Signal(flag, SIGNAL_MARKET_MANUAL_ORDER, thrift.MagicNumber());
            manualSignal.Value = OP_BUY;
            // Order* order = this.InitManualOrder(manualSignal.Value);
            // manualSignal.obj["Data"] = order.Persistent();
            thrift.PostSignal(manualSignal);
            return;
         }
      }
      
      if (lastChar=='p')
      {
         if (lparam=='s' || lparam=='S')
         {
            lastChar = 0;
            CreatePendingOrder(OP_SELL);
         }

         if (lparam=='b' || lparam=='B')
         {
            lastChar = 0;
            CreatePendingOrder(OP_BUY);
            return;
         }         
      }
      
      if (lparam==82) // r key
      {
         ReloadExpert();
      }
      
      switch(int(lparam))
      {
         case KEY_NUMLOCK_UP:    
         case KEY_UP:  
            FOREACH_ORDER(methods.globalOrders)
            {
               if (order.isPending())
               {  
                   if (order.isSelected())
                   {
                       order.ShiftUp();
                   }
               }  
            }
         break;         
         case KEY_NUMLOCK_DOWN:  
         case KEY_DOWN:     
            FOREACH_ORDER(methods.globalOrders)
            {
               if (order.isPending())
               {  
                   if (order.isSelected())
                   {
                       order.ShiftDown();
                   }
               }  
            }
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

      if ((lparam == 'd') || (lparam == 'D'))
      {
          FOREACH_ORDER(methods.globalOrders)
          {
             if (order.isPending())
             {
                if (order.isSelected())
                {
                    order.Delete();  
                    methods.globalOrders.DeleteCurrent();
                }
             }
          }
          ChartRedraw(methods.chartID);
      }       

      if ((lparam == 'u') || (lparam == 'U'))
      {
         methods.UpdateStopLossesTakeProfits(true);
      }
      
  } 
  
  if ( id >= CHARTEVENT_CUSTOM && id <= CHARTEVENT_CUSTOM_LAST )
  {
      this.controller.HandleSignal(id, lparam, dparam, sparam);
      return;
  }

  if (panel != NULL)
     panel.OnEvent(id,lparam,dparam,sparam);

}

void TradeExpert::ReloadExpert()
{
   string templateName = Utils.Service().Name() + ".tpl";
   ChartApplyTemplate(0, templateName);
}

void TradeExpert::DeInit(int Reason)
{
   if ((Reason != REASON_PARAMETERS) || (Reason != REASON_TEMPLATE))
   {
      //SaveGlobalProperties();
      if (methods != NULL)
         methods.SaveOrders();
   }

   DELETE_PTR(panel)

   DELETE_PTR(signals)

   DELETE_PTR(methods)
   
   DELETE_PTR(controller)
   

   ITradeService* thrift = Utils.Service();
   if (thrift != NULL)
      thrift.DeInit(Reason);
   Utils.Info(StringFormat("Expert <%s> closed with reason %s.", Utils.Symbol, ReasonToString(Reason)));
   
   DELETE_PTR(Utils);  
}

TradeExpert::~TradeExpert()
{
  

}

int TradeExpert::Init()
{   
   ITradeService* thrift = Utils.Service();
      
   if (!thrift.Init(true))
      return INIT_FAILED;
   
   if ( Digits() == 3 || Digits() == 5 )
   {
      actualSlippage = GET(Slippage)*10;
   }
   
   methods = new TradeMethods();
   Utils.SetTrade(methods);
   if ( GET(PanelSize) != PanelNone ) 
      panel = new TradePanel(GetPointer(this));
   signals = new TradeIndicators(methods, panel);
   methods.SetSignalsProcessor(signals);
   
   
   methods.Init();
   
   string initMessage = StringFormat("OnInit Expert On <%s>", Utils.Symbol);
   Utils.Info(initMessage);
   
   //TestOrders();
      
   if ( panel != NULL )
      panel.Init();

   methods.LoadOrders();
        
   methods.UpdateStopLossesTakeProfits(true);
   
   ChartNavigate(methods.ChartId(),CHART_END,0); 
   return (INIT_SUCCEEDED);
}


#ifdef __MQL5__

void TradeExpert::UpdateOrders()
{
   if (panel == NULL)
      return;
   // OrderSelection* orders = methods.GetOpenOrders();
   if (!Utils.IsTesting() || Utils.IsVisualMode())
      panel.Draw();
}

#endif


void TradeExpert::ProcessOrders()
{
   Utils.RefreshRates();
   Utils.Service().ProcessSignals();
   OrderSelection* orders = methods.GetOpenOrders();    
   OnTickPendingOrders(orders);
   ProcessStopOrders(orders);
   double CheckPrice = 0;
   double LossLevel = 0;
   double orderProfit = 0;
   int i = 0;
      
   int pendingDeleteCount = methods.CountOrdersByRole(ShouldBeClosed, orders);
   if (pendingDeleteCount > 0)
   {
      FOREACH_ORDER(orders)
      {
         // First close unclosed orders due to errors on Broker servers!!!
         if (order.Role() == ShouldBeClosed)
         {
            if (methods.CloseOrder(order))
            {  
               orders.DeleteCurrent();
            }
         }
      }
      orders.Sort();
   }
   
   if (panel != NULL)
   {
      panel.OrdersString = StringFormat("Default(%s) TotalProfit(%g)", EnumToString((ENUM_TRAILING)GET(TrailingType)), methods.GetProfit(orders)); 
   }
   
   ProcessIndicators(orders);
   
   FOREACH_ORDER(orders)
   {
      if (TrailByType(order))
         return;
   }
}

bool TradeExpert::ProcessIndicators(OrderSelection* orders)
{
   datetime currentBar = iTime(methods.Symbol, methods.Period, 0);
   if (SignalTFNow != currentBar) {
      SignalTFNow = currentBar;
      if (GET(SignalIndicator) == NoIndicator) // No signals - no auto trading
         return false;
      //signals.ProcessFilter();
      signals.RefreshIndicators();
      int countBUY = methods.CountOrdersByType(OP_BUY, orders);
      int countSELL = methods.CountOrdersByType(OP_SELL, orders);
      if (GET(AllowBUY) && BUYSession.IsSession() && (countBUY == 0)) 
      {
         signals.ProcessSignal();
         
      } else 
      if (GET(AllowSELL) && SELLSession.IsSession() && (countSELL == 0)) 
      {
         signals.ProcessSignal();
      }
   }
   return true;
} 


//+------------------------------------------------------------------+
bool TradeExpert::TrailByType(Order& order) 
{
   if ((GET(TrailingType) == TrailingManual) || order.Role() != RegularTrail)
       return false;              
   ENUM_TRAILING trailing = (ENUM_TRAILING)GET(TrailingType);
   if (order.TrailingType != TrailingDefault)
      trailing = order.TrailingType;
   switch(trailing)
   {
      case TrailingManual:
      case TrailingDefault:
         // Just skip trailing
         return false;
      case TrailingStairs:
      {
         double startDistance = GET(CoeffBE) * (double)GET(BrickSize);
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
         methods.TrailingByATR(order,methods.Period,1, GET(CoeffSL), GET(CoeffTP), false);
      return false;
      return false;
      case TrailingFiftyFifty:
         methods.TrailingFiftyFifty(order, methods.Period, 0.5, false);   // Good for EURUSD / EURAUD and for FlatTrend
      return false;
      return false;
      case TrailingByPriceChannel:
      {
         methods.TrailingByPriceChannel(order, (int)GET(NumBarsToAnalyze), (int)GET(TrailingIndent)); //actualStopLossLevel NumBarsFractals >= 10, TrailingIndent = 10
         return false;
      }
      case TrailingFilter:
      {
         signals.FI.Trail(order, (int)GET(TrailingIndent)); 
         return false;
      }
      case TrailingSignal:
      {
         signals.SI.Trail(order, (int)GET(TrailingIndent)); 
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

