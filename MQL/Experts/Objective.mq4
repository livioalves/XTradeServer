//+------------------------------------------------------------------+
//|  Expert Adviser Objec                              Objective.mq4 |
//|                                 Copyright 2013, Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"

#property strict
#include <stdlib.mqh>
#include <ThriftClient.mqh>
#include <TradeMethods.mqh>
#include <TradeSignals.mqh>
#include <TradePanel.mqh>

extern double Lots = 0.01;
extern int   TakeProfitLevel = 10;
extern int   StopLossLevel = 85;
extern int   Magic = 123456;
extern ushort ThriftPORT = 2010;
extern bool  AllowBUY = true;
extern bool  AllowSELL = true;
extern int   MaxOpenedTrades = 10;
extern int   Slippage = 10;
// Grid data
//--------------------------------------------------------------------
extern bool   AllowGRID = true;
extern int    GridStep = 65;
extern double GridMultiplier = 2.0;
extern int    GridProfit = 25;
// Stop Trailing data
//--------------------------------------------------------------------
extern int    TrailingIndent = 3;
extern ENUM_TIMEFRAMES  TrailingTimeFrame = PERIOD_M30;
extern ENUM_TRAILING  TrailingType = TrailingByFractals;
extern bool  TrailInLoss = true; // If true - stoploss should be defined!!!
extern int   NumBarsFractals = 5;
//--------------------------------------------------------------------
// Indicators 
extern bool  EnableNewsSignal = true;
//extern bool  EnableSentimentsLotSize = false;
extern ENUM_INDICATORS    TrendIndicator = EMAWMAIndicator;
extern ENUM_TIMEFRAMES   IndicatorTimeFrame = PERIOD_H4;
//--------------------------------------------------------------------
// News Params
extern int RaiseSignalBeforeEventMinutes = 30;
extern int NewsPeriodMinutes = 200;
extern ushort MinImportance = 1;
extern bool RevertNewsTrend = true;
//--------------------------------------------------------------------

//int grid_count = 0;
Order* grid_head = NULL;

ThriftClient* thrift  = NULL;
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
      // "gc" keyboad type closes the Grid on the current chart
      if (lparam=='G' || lparam=='g')
         lastChar = 'g';

      if ((lastChar=='g') && (lparam=='s' || lparam=='S')) { 
         lastChar = 0;
         Order* order = new Order(-1);
         order.lots = Lots;
         order.type = OP_SELL;
         order.takeProfit = Bid - TakeProfitLevel* Point; 
         if (AllowGRID == false)
             order.stopLoss = Ask + StopLossLevel * Point;

         order = methods.OpenOrder(order);
         if (order != NULL) {
            //methods.ChangeOrder(order, order.openPrice, SL, TP, 0, Red);
            signals.EventRaiseSoon = false;
            return;
         }
      }

      if ((lastChar=='g') && (lparam=='c' || lparam=='C')) { 
         lastChar = 0;
         grid_head = NULL;
         Alert("Closing Grid...");
         methods.CloseGrid();
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
   
   panel.Draw();
}

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   thrift = new ThriftClient(AccountNumber(), ThriftPORT, Magic);
   
   if ( Digits == 3 || Digits == 5 )
   {
      Slippage *= 10;
      TakeProfitLevel *= 10;
      StopLossLevel *= 10;
      GridStep *= 10;
   }
   
   string comment = "Objective";

   methods = new TradeMethods(Magic, MaxOpenedTrades, AllowBUY, AllowSELL, comment, Slippage);
   signals = new TradeSignals(thrift, MinImportance, NewsPeriodMinutes, RaiseSignalBeforeEventMinutes, RevertNewsTrend, IndicatorTimeFrame);
   panel = new TradePanel(comment, thrift, methods);
   
   string initMessage = StringFormat("OnInit %s Magic: %d, %d", comment, Magic, Digits);
   Print(initMessage);
   thrift.PostMessage(initMessage);
   
   //TestOrders();
  	  	
   panel.Init();
   return (INIT_SUCCEEDED);
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
      delete thrift;
      thrift = NULL;
   }
         
}

//+------------------------------------------------------------------+
int GetSignalOperationType()
{
   int signal = signals.TrendIndicator(TrendIndicator);
   
   if (EnableNewsSignal)
      signal = signals.GetNewsSignal(signal, panel.NewsString, panel.NewsStatString, panel.TrendString);
            
   if ((signal > 0) && AllowBUY)
      return (OP_BUY);
   if ((signal < 0) && AllowSELL)
      return (OP_SELL);
   return (-1);
}

double CalculateGridLotSize()
{
    return Lots * GridMultiplier;     
}

void ProcessOrders()
{
   OrderSelection* orders = methods.GetOpenOrders();
 
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
   
   if (AllowGRID) 
   {
      grid_head = methods.FindGridHead(orders, grid_count);
      gridProfit = methods.GetGridProfit(orders);
      if ((grid_count > 2) && (gridProfit < 0) && (MathAbs(gridProfit)>=(4*GridProfit)))
      {
         grid_head = NULL;
         methods.CloseGrid();
         return;
      }
      if ((gridProfit >= GridProfit))
      {
         grid_head = NULL;
         methods.CloseGrid();
         return;
      }
   } 
   if (grid_count > 0)
      panel.OrdersString = StringFormat("Orders: Grid Size(%d) GridProfit(%f)", grid_count, gridProfit); 
   else 
      panel.OrdersString = StringFormat("Orders: Profit(%f)", methods.GetProfit(orders)); 

   // STARTING POINT FOR OPENING ORDERS
   int op_type = GetSignalOperationType(); 
   if ((grid_head != NULL) && (op_type > 0) )
   {
       if ((grid_head.type != OP_BUY) && (countBUY == 0))
       {
            Order* order = new Order(-1);
            order.lots = Lots;
            order.type = OP_BUY;
            order.takeProfit = Bid + TakeProfitLevel* Point; 
            //if (AllowGRID == false)
               order.stopLoss = Ask - StopLossLevel * Point;
            order = methods.OpenOrder(order);
            if (order != NULL) 
            {
               signals.EventRaiseSoon = false;
               return;
            }
           
       }
       if ((grid_head.type != OP_SELL) && (countSELL == 0))
       {
            Order* order = new Order(-1);
            order.lots = Lots;
            order.type = OP_SELL;
            order.takeProfit = Bid - TakeProfitLevel* Point;
            //if (AllowGRID == false)
                order.stopLoss = Ask + StopLossLevel * Point;
            order = methods.OpenOrder(order);
            if (order != NULL)
            {
               signals.EventRaiseSoon = false;
               return;
            }

       }

   }
   if (AllowBUY && (op_type == OP_BUY) && (countBUY == 0) && (grid_head == NULL)) 
   {
      Order* order = new Order(-1);
      order.lots = Lots;
      order.type = op_type;
      order.takeProfit = Bid + TakeProfitLevel* Point; 
      if (AllowGRID == false)
         order.stopLoss = Ask - StopLossLevel * Point;
      order = methods.OpenOrder(order);
      if (order != NULL) 
      {
         signals.EventRaiseSoon = false;
         return;
      }
   }
   if (AllowSELL && (op_type == OP_SELL) && (countSELL == 0) && (grid_head == NULL)) 
   {
      Order* order = new Order(-1);
      order.lots = Lots;
      order.type = op_type;
      order.takeProfit = Bid - TakeProfitLevel* Point;
      if (AllowGRID == false)
          order.stopLoss = Ask + StopLossLevel * Point;
      order = methods.OpenOrder(order);
      if (order != NULL)
      {
         signals.EventRaiseSoon = false;
         return;
      }
   }
   
   FOREACH_ORDER(orders)
   {
         
      if (AllowGRID && order.Select()) 
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
            if ( LossLevel >= GridStep ) {
               order.SetRole(GridTail);
               
               grid_head = new Order(-1);
               grid_head.lots = CalculateGridLotSize();
               grid_head.type = order.type;
               grid_head.SetRole(GridHead);
               grid_head = methods.OpenOrder(grid_head);
               if (grid_head != NULL)
               {
                  Print(StringFormat("!!!Grid Started Ticket: %d", grid_head.ticket));
                  //return true;
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
                     if ((LossLevel > GridStep) && (signals.InNewsPeriod == false)) 
                     {
                        int trend = signals.TrendIndicator(TrendIndicator); // GetBWTrend();
                        if (((trend > 0) && (order.type == OP_SELL)) 
                         || ((trend < 0) && (order.type == OP_BUY))) 
                        {
                           grid_head.SetRole(GridTail);

                           grid_head = new Order(-1);
                           grid_head.lots = CalculateGridLotSize();
                           grid_head.type = order.type;
                           grid_head.SetRole(GridHead);
                           grid_head = methods.OpenOrder(grid_head);
                           if (grid_head != NULL) {
                              signals.EventRaiseSoon = false;
                              return;
                           }
                        }
                     }
                  }
               }
      }
      TrailByType(order);
   }

   /*
   for (i=0; i<OrdersTotal(); i++)
   {
      if (AllowGRID && OrderSelect(i, SELECT_BY_POS))
      {  
         tip = OrderType();
         if ((OrderSymbol()==Symbol()) && (OrderMagicNumber()==Magic))
         {
            orderProfit = CalcOrderRealProfit();
            if ((head_grid_ticket == -1) && (orderProfit < 0) && (grid_count == 1))
            {
               // this is a first order to start build grid
               if (tip == OP_BUY) 
               {
                  CheckPrice = Ask;
               } 
               else 
               {
                  CheckPrice = Bid;
               }
               LossLevel = MathAbs( CheckPrice - OrderOpenPrice() )/Point;
               if ( LossLevel >= GridStep ) { 
                  grid_optype = tip;
                  double lotsize = CalculateLotSize(grid_optype, OrderLots());
                  grid_ticket = methods.OpenOrder(tip, lotsize);
                  if (grid_ticket != -1)
                  {
                     head_grid_ticket = grid_ticket;
                     Print("!!!Grid Started Ticket: " + grid_ticket);
                     return true;
                  }
               }
            }
            if ((head_grid_ticket == -1) && (grid_count >1)) { // refind grid head if lost
               double currentLots = OrderLots();
               datetime currentOpenTime = OrderOpenTime();
               if ( (currentLots > lotSizeOfHead) || ((currentLots == lotSizeOfHead) && (HeadOpenTime < currentOpenTime))) {
                  lotSizeOfHead = currentLots;
                  HeadOpenTime = currentOpenTime;
                  head_grid_ticket = OrderTicket();
                  grid_optype = tip;
               }
            }
            if ( (head_grid_ticket != -1 ) && (tip == grid_optype) )
            {
               Profit += orderProfit;
            }
         } 
      }
   }
   */
   
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
         methods.TrailingByFractals(order,TrailingTimeFrame,NumBarsFractals,TrailingIndent,TrailInLoss);
      return;
      case TrailingByShadows:
         methods.TrailingByShadows(order,TrailingTimeFrame,NumBarsFractals,TrailingIndent,TrailInLoss);
      return;
      case TrailingByATR:
         methods.TrailingByATR(order,TrailingTimeFrame,NumBarsFractals,TrailingIndent,20,TrailingIndent,1,TrailInLoss);             
      return;
      case TrailingByMA:
         methods.TrailingByMA(order,TrailingTimeFrame,28,0,MODE_SMA,PRICE_MEDIAN,0,TrailingIndent); // EURAUD Trailing buy+sell 
      return;
      case TrailingStairs:
         methods.TrailingStairs(order,50,10);  
      return;   
      case TrailingFiftyFifty:
         methods.TrailingFiftyFifty(order, TrailingTimeFrame, 0.5, TrailInLoss);  
      return;
      case TrailingKillLoss:
         methods.KillLoss(order, 1.0);
      return;
   }
}

//+------------------------------------------------------------------+
/*
void DoTrailing()
{
   if (head_grid_ticket != -1)
      return;
   int tip, Ticket;
   for (int i=0; i<OrdersTotal(); i++)
   {
      if (OrderSelect(i, SELECT_BY_POS)==true)
      {  
         tip = OrderType();
         if (tip == grid_optype) 
               continue;              
         if ((tip==OP_SELL) && (AllowSELL == false))
            continue;        
         if ((tip==OP_BUY) && (AllowBUY == false))
            continue;        
         if ( (tip < 2) && (OrderSymbol()==Symbol()) && (OrderMagicNumber()==Magic)) 
         {            
            Ticket = OrderTicket();
            TrailByType(Ticket);
         }
      }
   }
}

*/