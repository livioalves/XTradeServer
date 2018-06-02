//+------------------------------------------------------------------+
//|  Expert Adviser Object                             Objective.mq4 |
//|                                 Copyright 2013, Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"

#property strict
#include <stdlib.mqh>
#include <FXMind\FXMindClient.mqh>
#include <FXMind\TradeMethods.mqh>
#include <FXMind\TradeSignals.mqh>
#include <FXMind\TradePanel.mqh>
#include <FXMind\SettingsFile.mqh>

sinput ENUM_MARKETSTATE MarketState = FlatTrend; // Market state on current chart
extern double LotsBUY = 0.1;
extern double LotsSELL = 0.2;
extern int   TakeProfitLevel = 10;
int   actualTakeProfitLevel = TakeProfitLevel;
extern int   StopLossLevel = 85;
int   actualStopLossLevel = StopLossLevel;
extern bool  AllowStopLossByDefault = false;
extern int ThriftPORT = 2010;
extern bool  AllowBUY = true;
extern bool  AllowSELL = true;
extern int   MaxOpenedTrades = 10;
extern int   Slippage = 10;
int   actualSlippage = Slippage;
// Grid data
//--------------------------------------------------------------------
extern bool   AllowGRIDBUY = false;
extern bool   AllowGRIDSELL = false;
extern int    GridStep = 65;
int   actualGridStep = GridStep;
extern double GridMultiplier = 2.0;
extern int    GridProfit = 25;
extern int    MaxGridOrders = 3;
// Stop Trailing data
//--------------------------------------------------------------------
extern int    TrailingIndent = 3;
extern ENUM_TIMEFRAMES  TrailingTimeFrame = PERIOD_M30;
extern ENUM_TRAILING  TrailingType = TrailingByFractals;
extern bool  TrailInLoss = true; // If true - stoploss should be defined!!!
extern int   NumBarsFractals = 5;
//--------------------------------------------------------------------
// Indicators 
extern ENUM_INDICATORS    TrendIndicator = EMAWMAIndicator;
extern ENUM_TIMEFRAMES   IndicatorTimeFrame = PERIOD_H4;
//--------------------------------------------------------------------
// News Params
extern int RaiseSignalBeforeEventMinutes = 30;
extern int NewsPeriodMinutes = 200;
extern int MinImportance = 1;
extern bool RevertNewsTrend = true;
//--------------------------------------------------------------------
extern ENUM_TRADE_PANEL_SIZE PanelSize = PanelSmall;
extern string comment = "";


Order* grid_head = NULL;

FXMindClient* thrift  = NULL;
TradeMethods* methods = NULL;
TradeSignals* signals = NULL;
TradePanel*   panel   = NULL;

char lastChar = 0;


void OnChartEvent(const int id,         // Event identifier  
                  const long& lparam,   // Event parameter of long type
                  const double& dparam, // Event parameter of double type
                  const string& sparam) // Event parameter of string type
{

  //--- the key has been pressed
  if( id == CHARTEVENT_KEYDOWN )
  {
      int bnumber = StrToInteger(CharToStr((uchar)lparam));
      
      // "gc" keyboad type closes the Grid on the current chart
      if (lparam=='G' || lparam=='g')
         lastChar = 'g';
         
      //if (lparam=='T' || lparam=='t')
      //   lastChar = 't';
         
      if (lparam=='O' || lparam=='o')
         lastChar = 'o';

         
      /*if ((lastChar=='t') && ((bnumber >=1) && (bnumber <=9)))
      {
            OrderSelection* orders = methods.GetOpenOrders(thrift.set);
            if (bnumber > orders.Total())
              bnumber = orders.Total();
            Order* order = orders.GetNodeAtIndex(bnumber-1);
            bnumber = -1;
            if (order != NULL)
            {
               Print(StringFormat("Change order %d Role to %s", order.ticket, EnumToString(GridTail)));
               order.SetRole(GridTail);
               panel.SetForceRedraw();
            }
      }*/
      
      if (lastChar=='o')
      {
      
         if (lparam=='s' || lparam=='S') 
         { 
            lastChar = 0;
            OpenSELLOrder(RegularTrail);
         }

         if (lparam=='b' || lparam=='B')
         { 
            lastChar = 0;
            OpenBUYOrder(RegularTrail);
            return;
         }
      }
      
      if (lastChar=='g')
      {      

         if (lparam=='c' || lparam=='C' || AllowGRIDBUY || AllowGRIDSELL) 
         { 
            lastChar = 0;
            grid_head = NULL;
            Alert("Closing Grid...");
            methods.CloseGrid();
            panel.SetForceRedraw();
         }
         
         if (lparam=='s' || lparam=='S' || AllowGRIDBUY || AllowGRIDSELL) 
         { 
            lastChar = 0;
            OpenSELLOrder(GridHead);
         }

         if (lparam=='b' || lparam=='B' || AllowGRIDBUY || AllowGRIDSELL)
         { 
            lastChar = 0;
            OpenBUYOrder(GridHead);
            return;
         }
         
         /*if ((bnumber >=1) && (bnumber <=9)) {
            OrderSelection* orders = methods.GetOpenOrders(thrift.set);
            if (bnumber > orders.Total())
              bnumber = orders.Total();
            Order* order = orders.GetNodeAtIndex(bnumber-1);
            bnumber = -1;
            if (order != NULL)
            {
               Print(StringFormat("Change order %d Role to %s", order.ticket, EnumToString(GridHead)));
               order.SetRole(GridHead);
               panel.SetForceRedraw();
            }

         }*/
      }
  } 
  panel.OnEvent(id,lparam,dparam,sparam);

}

//+------------------------------------------------------------------+
//| expert main function                                            |
//+------------------------------------------------------------------+
void OnTick()
{  	
   ProcessOrders();
   
   if ((!IsTesting()) || IsVisualMode()) 
      panel.Draw();
}

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if (IsTesting())
      comment = "Objective Tester";
   else 
   {
      comment = "Objective";
   }

   thrift = new FXMindClient((ushort)ThriftPORT, comment);
   if (thrift.MagicNumber <=0)
      return INIT_FAILED;
      
   thrift.Init();
   
   if ( Digits == 3 || Digits == 5 )
   {
      actualSlippage = Slippage*10;
      actualTakeProfitLevel = TakeProfitLevel*10;
      actualStopLossLevel = StopLossLevel*10;
      actualGridStep = GridStep * 10;
   }
      
   methods = new TradeMethods(thrift, MaxOpenedTrades, AllowBUY, AllowSELL, comment, actualSlippage);
   signals = new TradeSignals(thrift, (ushort)MinImportance, NewsPeriodMinutes, RaiseSignalBeforeEventMinutes, IndicatorTimeFrame);
   panel = new TradePanel(comment, thrift, methods, PanelSize);

   methods.SetMarketState(MarketState);
   
   SaveGlobalProperties();
   
   string initMessage = StringFormat("OnInit %s MagicNumber: %d", comment, thrift.MagicNumber);
   Print(initMessage);
   thrift.PostMessage(initMessage);
   
   //TestOrders();
  	  	   
   methods.LoadOrders(thrift.set);
   
   panel.Init();

   return (INIT_SUCCEEDED);
}

/*
void LoadGlobalProperties()
{
   //set.GetIniKey("", "MarketState", MarketState);
   set.GetIniKey(set.globalSection, "Lots", Lots);
   set.GetIniKey(set.globalSection, "TakeProfitLevel", TakeProfitLevel);
   set.GetIniKey(set.globalSection, "StopLossLevel", StopLossLevel);
   set.GetIniKey(set.globalSection, "AllowStopLossByDefault", AllowStopLossByDefault);
   set.GetIniKey(set.globalSection, "ThriftPORT", ThriftPORT);
   set.GetIniKey(set.globalSection, "MaxOpenedTrades", MaxOpenedTrades);
   set.GetIniKey(set.globalSection, "AllowUY", AllowUY);
   set.GetIniKey(set.globalSection, "AllowSELL", AllowSELL);
   set.GetIniKey(set.globalSection, "Slippage", Slippage);
   set.GetIniKey(set.globalSection, "AllowGRIDBUY", AllowGRIDBUY);
   set.GetIniKey(set.globalSection, "AllowGRIDSELL", AllowGRIDSELL);
   set.GetIniKey(set.globalSection, "GridStep", GridStep);
   set.GetIniKey(set.globalSection, "GridMultiplier", GridMultiplier);
   set.GetIniKey(set.globalSection, "GridProfit", GridProfit);
   set.GetIniKey(set.globalSection, "MaxGridOrders", MaxGridOrders);
   set.GetIniKey(set.globalSection, "TrailingIndent", TrailingIndent);

   int ttf = TrailingTimeFrame;
   set.GetIniKey(set.globalSection, "TrailingTimeFrame", ttf);
   TrailingTimeFrame = (ENUM_TIMEFRAMES)ttf;
   int tt = TrailingType;
   set.GetIniKey(set.globalSection, "TrailingType", tt);
   TrailingType = (ENUM_TRAILING)tt;
   set.GetIniKey(set.globalSection, "TrailInLoss", TrailInLoss);
   set.GetIniKey(set.globalSection, "NumBarsFractals", NumBarsFractals);
   int ti = TrendIndicator;
   set.GetIniKey(set.globalSection, "TrendIndicator", ti);
   TrendIndicator = (ENUM_INDICATORS)ti;
   int itf = IndicatorTimeFrame;
   set.GetIniKey(set.globalSection, "IndicatorTimeFrame", itf);
   IndicatorTimeFrame = (ENUM_TIMEFRAMES)itf;
   set.GetIniKey(set.globalSection, "RaiseSignalBeforeEventMinutes", RaiseSignalBeforeEventMinutes);
   set.GetIniKey(set.globalSection, "NewsPeriodMinutes", NewsPeriodMinutes);
   set.GetIniKey(set.globalSection, "MinImportance", MinImportance);
   set.GetIniKey(set.globalSection, "RevertNewsTrend", RevertNewsTrend);

}
*/

void SaveGlobalProperties()
{
   thrift.set.SetGlobalParam("MarketState", (int)MarketState);
   thrift.set.SetGlobalParam("LotsBUY", LotsBUY);
   thrift.set.SetGlobalParam("LotsSELL", LotsSELL);
   thrift.set.SetGlobalParam("TakeProfitLevel", TakeProfitLevel);
   thrift.set.SetGlobalParam("StopLossLevel", StopLossLevel);
   thrift.set.SetGlobalParam("AllowStopLossByDefault", AllowStopLossByDefault);
   thrift.set.SetGlobalParam("ThriftPORT", ThriftPORT);
   thrift.set.SetGlobalParam("MaxOpenedTrades", MaxOpenedTrades);
   thrift.set.SetGlobalParam("AllowBUY", AllowBUY);
   thrift.set.SetGlobalParam("AllowSELL", AllowSELL);
   thrift.set.SetGlobalParam("Slippage", Slippage);
   thrift.set.SetGlobalParam("AllowGRIDBUY", AllowGRIDBUY);
   thrift.set.SetGlobalParam("AllowGRIDSELL", AllowGRIDSELL);
   thrift.set.SetGlobalParam("GridStep", GridStep);
   thrift.set.SetGlobalParam("GridMultiplier", GridMultiplier);
   thrift.set.SetGlobalParam("GridProfit", GridProfit);
   thrift.set.SetGlobalParam("MaxGridOrders", MaxGridOrders);
   thrift.set.SetGlobalParam("TrailingIndent", TrailingIndent);
   thrift.set.SetGlobalParam("TrailingTimeFrame", (int)TrailingTimeFrame);
   thrift.set.SetGlobalParam("TrailingType", (int)TrailingType);
   thrift.set.SetGlobalParam("TrailInLoss", TrailInLoss);
   thrift.set.SetGlobalParam("NumBarsFractals", NumBarsFractals);
   thrift.set.SetGlobalParam("TrendIndicator", (int)TrendIndicator);
   thrift.set.SetGlobalParam("IndicatorTimeFrame", IndicatorTimeFrame);
   thrift.set.SetGlobalParam("RaiseSignalBeforeEventMinutes", RaiseSignalBeforeEventMinutes);
   thrift.set.SetGlobalParam("NewsPeriodMinutes", NewsPeriodMinutes);
   thrift.set.SetGlobalParam("MinImportance", MinImportance);
   thrift.set.SetGlobalParam("RevertNewsTrend", RevertNewsTrend);
   thrift.set.SetGlobalParam("comment", comment);
   
   //methods.SaveOrders(thrift.set);

}


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

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{      
   if (thrift.set != NULL)
   {
      if (reason != REASON_PARAMETERS)
      {
         SaveGlobalProperties();
         if (thrift.set != NULL)
            methods.SaveOrders(thrift.set);
      }
   }

   if (panel != NULL) 
   {
      delete panel;
      panel = NULL;
   }

   if (methods != NULL)
   {
      delete methods;
      methods = NULL;
   }

   if (signals != NULL)
   {
      delete signals;
      signals = NULL;
   }

   if (thrift != NULL)
   {
      thrift.DeInit(reason);
      delete thrift;
      thrift = NULL;
   }
         
}

int indiSignal = 0;
string trendString = "NEUTRAL";
//+------------------------------------------------------------------+
int GetSignalOperationType()
{
   int signal = signals.TrendIndicator(TrendIndicator);
   
   if ((signal != indiSignal) && (signal != 0))
   {
      indiSignal = signal;
      trendString = "NEUTRAL";
      if (signal < 0)
         trendString = "SELL";
      else 
         if (signal > 0)
              trendString = "BUY";
   }
                 
   panel.TrendString = StringFormat("%s On %s On %s", trendString, EnumToString(IndicatorTimeFrame), EnumToString(TrendIndicator));
   
   bool just_raised = signals.GetNewsSignal(signals.Last, panel.NewsStatString);
   if(  just_raised && signals.Last.OnAlert())
   {
      //Print(signals.Last.eventInfo.ToString());
      if (RevertNewsTrend)
         signals.Last.Value = -1 * indiSignal*signals.Last.Value;
      else
         signals.Last.Value = indiSignal*signals.Last.Value;
      if (signals.Last.Value > 0)
         return (OP_BUY);
      if (signals.Last.Value < 0)
         return (OP_SELL);
   }    
   return (-1);
}

double CalculateGridLotSize(int op)
{
    if (op == OP_BUY)
       return LotsBUY * GridMultiplier;     
    if (op == OP_SELL)
       return LotsSELL * GridMultiplier;     
    return LotsBUY;
}

Order* OpenBUYOrder(ENUM_ORDERROLE role)
{
      Order* order = new Order(-1);
      order.type = OP_BUY;
      if (role == RegularTrail)
      {
         order.lots = LotsBUY;
         order.takeProfit = Bid + actualTakeProfitLevel* Point; 
         if (AllowStopLossByDefault)
            order.stopLoss = Ask - actualStopLossLevel * Point;
      }
      else if (AllowGRIDBUY && (role == GridHead))
      {
         order.lots = CalculateGridLotSize(OP_BUY);
      }
      order = methods.OpenOrder(order);
      if (order != NULL) 
      {
         if (AllowGRIDBUY && (role == GridHead))
             grid_head = order;
         signals.Last.Handled = true;
         return order;
      }
      return NULL;
}

Order* OpenSELLOrder(ENUM_ORDERROLE role)
{
      Order* order = new Order(-1);
      order.type = OP_SELL;
       if (role == RegularTrail)
      {
         order.lots = LotsSELL;
         order.takeProfit = Bid - actualTakeProfitLevel* Point;
         if (AllowStopLossByDefault)
             order.stopLoss = Ask + actualStopLossLevel * Point;
      } 
      else if (AllowGRIDSELL && (role == GridHead))
      {
         order.lots = CalculateGridLotSize(OP_SELL);
      }
      order = methods.OpenOrder(order);
      if (order != NULL)
      {
         signals.Last.Handled = true;
         return order;
      }
      return NULL;
}

void ProcessOrders()
{
   OrderSelection* orders = methods.GetOpenOrders(thrift.set);
    
   int countBUY = methods.CountOrdersByType(OP_BUY, orders);
   int countSELL = methods.CountOrdersByType(OP_SELL, orders);
   int grid_count = 0;
   double CheckPrice = 0;
   double LossLevel = 0;
   double orderProfit = 0;
   int i = 0;
   double gridProfit = 0; 
   
   int pendingDeleteCount = methods.CountOrdersByRole(ShouldBeClosed, orders);
   if (pendingDeleteCount > 0)
   {
      Print(StringFormat("!!!!!Delete hard stuck Orders count = %d!!!!!!!", pendingDeleteCount));
      FOREACH_ORDER(orders)
      {
         // First close unclosed orders due to errors on Broker servers!!!
         if (order.Role() == ShouldBeClosed)
         {
            if (methods.CloseOrder(order, clrRed))
            {  
               orders.DeleteCurrent();
               //return;
            }
         }
      }
      orders.Sort();
   }
   
   if (AllowGRIDBUY || AllowSELL) 
   {
      grid_head = methods.FindGridHead(orders, grid_count);
      gridProfit = methods.GetGridProfit(orders);
      if ((gridProfit >= GridProfit))
      {
         grid_head = NULL;
         
         methods.CloseGrid();
         panel.SetForceRedraw();
         return;
      }
      if ((grid_count >= MaxGridOrders) && (gridProfit < 0) && (MathAbs(gridProfit)>=(3*GridProfit)))
      {
         grid_head = NULL;
         methods.CloseGrid();
         panel.SetForceRedraw();
         return;
      }
   } 
   if (grid_count > 0)
      panel.OrdersString = StringFormat("Orders: Grid Size(%d) GridProfit(%g)", grid_count, gridProfit); 
   else 
      panel.OrdersString = StringFormat("Orders: Profit(%g)", methods.GetProfit(orders)); 

   // STARTING POINT FOR OPENING ORDERS
   int op_type = GetSignalOperationType();    
   if ((grid_head != NULL) && (op_type > 0) )
   {
       if (AllowBUY && (grid_head.type != OP_BUY) && (countBUY == 0))
       {
           OpenBUYOrder(RegularTrail);
           return;     
       }
       if (AllowSELL && (grid_head.type != OP_SELL) && (countSELL == 0))
       {
           OpenSELLOrder(RegularTrail);
           return;
       }
   }
   
   if (AllowBUY && (op_type == OP_BUY) && (countBUY == 0) && (grid_head == NULL)) 
   {
      OpenBUYOrder(RegularTrail);
      return;
   }
   if (AllowSELL && (op_type == OP_SELL) && (countSELL == 0) && (grid_head == NULL)) 
   {
      OpenSELLOrder(RegularTrail);
      return;
   }
      
   FOREACH_ORDER(orders)
   {
      if ((AllowGRIDBUY || AllowGRIDSELL) && order.Select()) 
      {

         orderProfit = order.RealProfit();
         if ((!order.isGridOrder()) && (grid_head == NULL) && (orderProfit < 0))
         {
            //this is a first order to start build grid
            if (order.type == OP_BUY) 
            {
               CheckPrice = Ask;
            } 
            else 
            {
               CheckPrice = Bid;
            }
            LossLevel = MathAbs( CheckPrice - order.openPrice )/Point;
            if ( LossLevel >= methods.GetGridStepValue() ) {
               order.SetRole(GridTail);
               if (order.type == OP_BUY)
                  grid_head = OpenBUYOrder(GridHead);
               else 
                  grid_head = OpenSELLOrder(GridHead);
               if (grid_head != NULL)
               {
                  Print(StringFormat("!!!Grid Started Ticket: %d", grid_head.ticket));
                  return;
               }
            }
         } else 
               if (grid_head != NULL)
               {
                  if ((order.ticket == grid_head.ticket) && (order.Role() == GridHead))
                  {
                     if (grid_head.type == OP_BUY)
                     {
                        CheckPrice = Bid;
                        LossLevel = (grid_head.openPrice - CheckPrice)/Point;
                     } 
                     else 
                     {
                        CheckPrice = Ask;
                        LossLevel = (CheckPrice - grid_head.openPrice)/Point;
                     }
                     if ((LossLevel > methods.GetGridStepValue()) && (signals.InNewsPeriod == false)) 
                     {
                        int trend = signals.TrendIndicator(TrendIndicator); // GetBWTrend();
                        if (((trend > 0) && (order.type == OP_SELL)) 
                         || ((trend < 0) && (order.type == OP_BUY))) 
                        {
                           grid_head.SetRole(GridTail);

                           if (order.type == OP_BUY)
                              grid_head = OpenBUYOrder(GridHead);
                           else 
                              grid_head = OpenSELLOrder(GridHead);
                           if (grid_head != NULL)
                           {
                              return;
                           }
                        }
                     }
                  }
               }
      }
      TrailByType(order);
   }
   signals.Last.Handled = true;
}

//+------------------------------------------------------------------+
void TrailByType(Order& order) 
{
   if (order.Role() != RegularTrail)
       return;
   ENUM_TRAILING trailing = TrailingType;
   if (order.TrailingType != TrailingDefault)
      trailing = order.TrailingType;
   switch(trailing)
   {
      case TrailingByFractals:
      case TrailingDefault:
         methods.TrailingByFractals(order,TrailingTimeFrame,NumBarsFractals,TrailingIndent,TrailInLoss);  // good for USDCHF USDJPY and by default
      return;
      case TrailingByShadows:
         methods.TrailingByShadows(order,TrailingTimeFrame,NumBarsFractals,TrailingIndent,TrailInLoss);
      return;
      case TrailingByATR:
         methods.TrailingByATR(order,TrailingTimeFrame,14,TrailingIndent,28,TrailingIndent,1,TrailInLoss);             
      return;
      case TrailingByMA:
         methods.TrailingByMA(order,TrailingTimeFrame,28,0,MODE_SMA,PRICE_MEDIAN,0,TrailingIndent); // EURAUD Trailing buy+sell 
      return;
      case TrailingStairs:
         methods.TrailingStairs(order,50,10);  
      return;   
      case TrailingFiftyFifty:
         methods.TrailingFiftyFifty(order, TrailingTimeFrame, 0.5, TrailInLoss);   // Good for EURUSD / EURAUD and for FlatTrend
      return;
      case TrailingKillLoss:
         methods.KillLoss(order, 1.0);
      return;
   }
}
