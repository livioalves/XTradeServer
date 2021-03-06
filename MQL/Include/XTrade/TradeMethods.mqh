#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <stdliberr.mqh>
#include <XTrade\Orders.mqh>
#include <XTrade\ITradeService.mqh>
#include <XTrade\PendingOrder.mqh>
#include <XTrade\MedianRenko\TradeFunctions.mqh>

#ifndef  SHOW_INDICATOR_INPUTS
#define SHOW_INDICATOR_INPUTS
#endif

//
// You need to include the MedianRenko.mqh header file
//
//#include <XTrade/MedianRenko/MedianRenko.mqh>

class TradeIndicators;

#include <XTrade\TradeIndicators.mqh>

class TradeMethods : public ITrade 
{
protected:
    datetime sdtPrevtime;
    string   EANameString;
   //+------------------------------------------------------------------+
public:
   OrderSelection globalOrders;
   CMarketOrder         *orderHandler;

   ITradeService *thrift;
   TradeIndicators* signals;
   string Symbol;
   double Point;
   int Digits;
   ENUM_TIMEFRAMES Period;
   color    TrailingColor;
   double StopLevelPoints;
   double trailDelta;

   long        chartID;
   int         subWindow;
   int         indiSubWindow; 
   TYPE_TREND  trend;

   TradeMethods()
      :globalOrders(MaxOpenedTrades)
   {
       thrift = Utils.Service();
       sdtPrevtime = 0;
       
       TrailingColor = Yellow;  
       Symbol = _Symbol;
       Point = _Point;
       Digits = _Digits;
       Period = _Period;
       StopLevelPoints = StopLevelPoints;
       //lastDealTicket = 0;
       trend = LATERAL;
       
       chartID = ChartID();
       subWindow = 0;
       indiSubWindow = subWindow + 1;//(int)ChartGetInteger(chartID, CHART_WINDOWS_TOTAL);
   }
   
   void Init() {
      CMarketOrderParameters params;
      {
         params.m_async_mode        = false;
         params.m_magic             = thrift.MagicNumber();
         params.m_deviation         = GET(Slippage);
         params.m_type_filling      = ORDER_FILLING_FOK;
         
         
         params.numberOfRetries     = GET(MoreTriesOpenOrder)?2:1;
         params.busyTimeout_ms      = 3000; 
         params.requoteTimeout_ms   = 3000;         
      }
   
      DELETE_PTR(orderHandler);
      orderHandler = new CMarketOrder(params);
   }
   
   bool CloseOrder(Order* order) 
   {
      order.MarkToClose();
      return orderHandler.CloseAll(order.symbol);
   }

      
   ~TradeMethods()
   {
      DELETE_PTR(orderHandler);

      globalOrders.Clear();
   }
         
   OrderSelection* Orders() 
   {
      return &globalOrders;
   }

   void SetSignalsProcessor(TradeIndicators* sig)
   {
       signals = sig;
   }
   
   long ChartId() const       { return chartID; }
   int SubWindow() const     { return subWindow; }
   int IndiSubWindow() const { return indiSubWindow; }
   
   void SetTrend(TYPE_TREND t) {  trend = t; }

   TYPE_TREND Trend() 
   {
      return trend;
   }

   void SetTrailDelta(double td) 
   {
      this.trailDelta = td;
   }


   //+------------------------------------------------------------------+ 
   bool AllowVStops()
   {
      return GET(AllowVirtualStops);
   }
   //+------------------------------------------------------------------+ 
   double ContractsToLots(int op_type, ushort nContracts)  
   {
      if (op_type == OP_BUY)
      {
         return GET(LotsBUY) * nContracts;
      }
      if (op_type == OP_SELL)
      {
         return GET(LotsSELL) * nContracts;
      }
      return GET(LotsSELL) * nContracts;
   }
   //+------------------------------------------------------------------+ 
   double StopLoss(double price, int op_type)
   {
      double actualStopLossLevel = DefaultStopLoss();
      if (op_type == OP_BUY)
      {
          return price - actualStopLossLevel * _Point;
      }
      if (op_type == OP_SELL)
      {
          return price + actualStopLossLevel * _Point;
      }
      return 0;
   }
   
   double TakeProfit(double price, int op_type)
   {
      double actualTakeProfitLevel = DefaultTakeProfit();
      if (op_type == OP_BUY)
      {
         return price + actualTakeProfitLevel* _Point; 
      }
      if (op_type == OP_SELL)
      {
         return price - actualTakeProfitLevel* _Point; 
      }
      return 0;
   }
   

   virtual double  TrailDelta() 
   { 
      return trailDelta; 
   }

   virtual void AddUpdateByTicket(long Ticket)
   {
      Order* oldOrder = globalOrders.SearchOrder(Ticket);
      if (oldOrder != NULL)
      {
         globalOrders.Fill(oldOrder);
      } else 
      {
         Order* order = NULL;
         order = new Order(Ticket);
         globalOrders.Fill(order);
         globalOrders.Add(order);
      }
   }
   
   void SaveOrders()
   {
      OrderSelection* orders = GetOpenOrders();
      //string orderSection = "";
      //string ActiveOrdersList = "";
      Signal retSignal(SignalToServer, SIGNAL_ACTIVE_ORDERS, thrift.MagicNumber());

      //SettingsFile *set = thrift.Settings();
      FOREACH_ORDER(orders)
      {
         //orderSection = order.OrderSection();
         /*if (set != NULL)
         {
            //Print("Save Order: "+ orderSection);
            set.SetParam(orderSection, "ticket", order.Id());
            set.SetParam(orderSection, "openPrice", order.openPrice);
            set.SetParam(orderSection, "role", order.Role());
            set.SetParam(orderSection, "TrailingType", order.TrailingType);
            set.SetParam(orderSection, "stopLoss", order.StopLoss(false));
            set.SetParam(orderSection, "takeProfit", order.TakeProfit(false));
            set.SetParam(orderSection, "lots", order.lots);
            set.SetParam(orderSection, "profit", order.Profit());
            if (StringLen(order.signalName) > 0)
               set.SetParam(orderSection, "signalName", order.signalName);
         }*/
         //set.SetParam(orderSection, "comment", order.comment);
         
         retSignal.obj["Data"].Add(order.Persistent());

         //ActiveOrdersList += orderSection;
         //ActiveOrdersList += "|"; 
      }
      //ActiveOrdersList += Constants::GLOBAL_SECTION_NAME;
      string strData = retSignal.obj["Data"].Serialize();
      thrift.SaveAllSettings("", strData);
   }
   
   void LoadOrders()
   {
      OrderSelection* orders = GetOpenOrders();
      FOREACH_ORDER(orders)
      {
         LoadOrder(order);
      }
   }
   
   long GeneratePendingOrderTicket(int type)
   {
      long ticket = (type == OP_BUY)?PENDING_BUY_TICKET:PENDING_SELL_TICKET;
      ticket -= thrift.MagicNumber();
      Order* order = NULL;
      while (true)
      {
         order = globalOrders.SearchOrder(ticket);
         if (order == NULL)
            break;
         ticket--;
      }
      return ticket;
   }
   
   /*
   void LoadPendingOrders(SettingsFile* set)
   {
      if (set != NULL)
      {
         for (int i = 0; i<2; i++)
         {
            int pendingBUYTicket = PENDING_BUY_TICKET - i + thrift.MagicNumber();
            int pendingSELLTicket = PENDING_SELL_TICKET - i + thrift.MagicNumber();
            if (set.OrderSectionExist(pendingBUYTicket, Order::OrderSection(pendingBUYTicket)))
            {
               PendingOrder* order = new PendingOrder(OP_BUY, pendingBUYTicket);
               string orderSection = order.OrderSection();
               set.GetIniKey(orderSection, "lots", order.lots);
               set.GetIniKey(orderSection, "openPrice", order.openPrice);
               int role = 0;
               set.GetIniKey(orderSection, "role", role);
               order.SetRole((ENUM_ORDERROLE)role);
               int tt = 0;
               set.GetIniKey(orderSection, "TrailingType", tt);
               order.TrailingType = (ENUM_TRAILING)tt;
               long t = order.Id();
               set.GetIniKey(orderSection, "ticket", t);
               order.SetId(t);
               double tp = 0;         
               set.GetIniKey(orderSection, "takeProfit", tp);
               order.setTakeProfit(tp);
               double sl = 0;
               set.GetIniKey(orderSection, "stopLoss", sl);
               order.setStopLoss(sl);
               Utils.Trade().Orders().Add(order);
               order.InitLoaded();
               order.doSelect(false);
               if (!Utils.IsTesting())
                  Utils.Info(order.Id(), StringFormat("Order %s %d restored successfully ", EnumToString(order.Role()), order.Id()));
            }
            if (set.OrderSectionExist(pendingSELLTicket, Order::OrderSection(pendingSELLTicket)))
            {
               PendingOrder* order = new PendingOrder(OP_SELL, pendingSELLTicket);
               string orderSection = order.OrderSection();
               set.GetIniKey(orderSection, "lots", order.lots);
               set.GetIniKey(orderSection, "openPrice", order.openPrice);
               int role = 0;
               set.GetIniKey(orderSection, "role", role);
               order.SetRole((ENUM_ORDERROLE)role);
               int tt = 0;
               set.GetIniKey(orderSection, "TrailingType", tt);
               order.TrailingType = (ENUM_TRAILING)tt;
               double sl = 0;
               long t = order.Id();
               set.GetIniKey(orderSection, "ticket", t);
               double tp = 0;
               set.GetIniKey(orderSection, "takeProfit", tp);
               order.setTakeProfit(tp);
               order.SetId(t);
               set.GetIniKey(orderSection, "stopLoss", sl);
               order.setStopLoss(sl);
               Utils.Trade().Orders().Add(order);
               order.InitLoaded();
               order.doSelect(false);
               if (!Utils.IsTesting())
                  Utils.Info(order.Id(), StringFormat("Order %s %d restored successfully ", EnumToString(order.Role()), order.Id()));
            }
         }
      }
   }
*/
   
   void LoadOrder(Order* order)
   {
      // string orderSection = order.OrderSection();
      /*SettingsFile* set = thrift.Settings();
      if (set != NULL)
      {
         long t = order.Id();
         set.GetIniKey(orderSection, "ticket", t);
         order.SetId(t);
         set.GetIniKey(orderSection, "openPrice", order.openPrice);
         set.GetIniKey(orderSection, "lots", order.lots);
         int role = 0;
         set.GetIniKey(orderSection, "role", role);
         order.SetRole((ENUM_ORDERROLE)role);
         int tt = 0;
         set.GetIniKey(orderSection, "TrailingType", tt);
         order.TrailingType = (ENUM_TRAILING)tt;
         double sl = 0;
         set.GetIniKey(orderSection, "stopLoss", sl);
         order.setStopLoss(sl);
         double tp = 0;
         set.GetIniKey(orderSection, "takeProfit", tp);
         order.setTakeProfit(tp);
      } */
      if (!Utils.IsTesting())
         Print(StringFormat("Order %d restored successfully ", order.Id()));
   }
      
   void LogError(string message)
   {
       Comment(message);
   }
   
   double RiskAmount(double percent)
   {
      return Utils.AccountBalance()*percent;
   }
   
   OrderSelection* GetOpenOrders()
   {
      globalOrders.MarkOrdersAsDirty();
      long ticket = 0;
      string _symbol = _Symbol;
      for (int i = Utils.OrdersTotal() - 1; i >= 0; i-- )
      {     
         if (Utils.SelectOrderByPos(i))
         {
            ticket = Utils.OrderTicket();
            if (_symbol == Utils.OrderSymbol()) 
            {
               AddUpdateByTicket(ticket);
            } 
         }
      }
      
      globalOrders.RemoveDirtyObsoleteOrders();
      return &globalOrders;
   }
   
        
   //+------------------------------------------------------------------+
   int CountOrdersByType(int op_type, OrderSelection& orders) 
   {
      int count = 0;
      FOREACH_ORDER(orders)
      {
         if (order.type == op_type)
             count++;
      }
      return(count);
   }
   
   //+------------------------------------------------------------------+
   int CountOrdersByRole(ENUM_ORDERROLE role, OrderSelection& orders) 
   {
      int count = 0;
      FOREACH_ORDER(orders)
      {
         if (order.Role() == role)
             count++;
      }
      return(count);
   }
   
   int GetDailyATR() const
   {
      int realGridStep = (int)double(signals.GetATR(1)/Point);
      //int realGridStep = (int)double(Utils.PercentileATR(Symbol, PERIOD_D1, SL_PERCENTILE, (int)GET(NumBarsToAnalyze), 0)/Point);
      return realGridStep;
   }
   
   int ATROnIndicator(double rank)
   {
      // double percentilePt = RISK_ATR * Utils.PercentileATR(Symbol, PERIOD_D1, rank, (int)GET(NumBarsToAnalyze), 0)/Point;
      double percentilePt = RISK_ATR*(int)double(signals.GetATR(1)/Point);
      return (int)percentilePt;
   }
   
   int TechStopLoss() {
      double price = Utils.Ask();// MathAbs(Utils.Ask()-Utils.Bid())/2;
      int sl = (int)(price*0.002/this.Point); 
      return sl;
   }
      
   int DefaultStopLoss()
   {
      double sl = TechStopLoss()*GET(CoeffSL);//ATROnIndicator(SL_PERCENTILE)*GET(CoeffSL)*STOP_LUFT;
      //double sl = GET(BrickSize)*GET(CoeffSL);
      // Adjust stop level
      //int slp = Utils.StopLevel();
      //if (slp > 0)
      //{
         //if (sl < slp)
         //   sl = MathMax( slp, slp*GET(CoeffSL));
      //}
      return (int)MathCeil(sl); 
   }
   
   int DefaultTakeProfit()
   {
      double tp = TechStopLoss()*GET(CoeffTP);//ATROnIndicator(SL_PERCENTILE)*GET(CoeffTP);
      //double tp = GET(BrickSize)*GET(CoeffTP);
      // Adjust stop level
      //int slp = Utils.StopLevel();
      //if (slp > 0)
      //{
         //if (tp < slp)
         //   tp = MathMax( slp, slp*GET(CoeffTP));
      //}
      return (int)MathCeil(tp); 
   }   
   
   
   void UpdateStopLossesTakeProfits(bool forceUpdate) 
   {
      FOREACH_ORDER(globalOrders)
      {
          if (order.isPending())
          {
               if (forceUpdate)
               {
                  order.doSelect(false);
               }
          } else 
          {
              order.updateTP(forceUpdate);
              order.updateSL(forceUpdate);
          }
      }
      if (forceUpdate) 
      {
         if (!Utils.IsTesting())
            SaveOrders();
         ChartRedraw(this.ChartId());
      }
   }
   
   void HandleNumbers(uchar sym) 
   {
      ushort nContracts = (ushort)StringToInteger(CharToString(sym));
      FOREACH_ORDER(globalOrders)
      {
          if (order.isPending())
          {
               if (order.isSelected())
               {
                  order.SetNContracts(nContracts);
               }
          }
      }
   }
   
   //+------------------------------------------------------------------+
   double GetProfit(OrderSelection& orders) 
   {
      int count = 0;
      double profit = 0;
      FOREACH_ORDER(orders)
      {
         profit += order.RealProfit();
      }
      return profit;
   }
      
   void CloseTrailingPositions(int op_type) 
   {
      datetime current = TimeCurrent();
      // CLOSE ALL GRID ORDERS
      int count = globalOrders.Total();
      if (count > 0)
         Print(StringFormat("++++++++++Close Trailing Positions(%d):++++++++++", count));
      FOREACH_ORDER(globalOrders)
      {
         //if (order.Select())
         //{
         //   order.openTime = Utils.OrderOpenTime();
         //}
         if ((order.Role() == RegularTrail) && (order.type == op_type) )// && (Utils.TimeMinute(order.openTime) > 120))
         {
            //if (order.Select())
            //{
            //   if (order.RealProfit() < 1)
                  order.SetRole(ShouldBeClosed);
            //}
            /*
            if (CloseOrder(order, clrMediumSpringGreen))
            {
               Print(StringFormat("CLOSED Trailing item: %s", order.ToString()));
               globalOrders.DeleteCurrent();
            }
            */
         }
      }
      //globalOrders.Sort();
   }

   //+------------------------------------------------------------------+
   int CountAllTrades()
   {
       return globalOrders.Total();
   }
   
   void DeletePendingOrders()
   {
      FOREACH_ORDER(globalOrders)
      {
         if (order.isPending())
         {
            order.Delete();
            globalOrders.DeleteCurrent();
         }
      }
   }
   
   void DeletePendingOrder(PendingOrder* toDelete)
   {
      if ( toDelete == NULL ) 
         return;
      FOREACH_ORDER(globalOrders)
      {
         if (order.isPending())
         {
            if (toDelete.Id() == order.Id()) 
            {
                order.Delete();
                globalOrders.DeleteCurrent();
                break;
            }
         }
      }
   }
   //+------------------------------------------------------------------+
   Order* OpenOrder(Order& order) 
   {
       if (!Utils.CheckRiskManager()) // Check if RISK Manager allows trading.
           return NULL;
           
       if (CountAllTrades() >= MaxOpenedTrades)
       {
          Utils.Info(StringFormat("Reached maximum of orders! %d. No new orders!", MaxOpenedTrades));
          delete &order;
          return NULL;
       }
       if ((GET(AllowBUY) == false)&& (order.type==OP_BUY))
       {
          delete &order;
          Utils.Info("BUY Orders are not allowed");
          return NULL; 
       }
       if ((GET(AllowSELL) == false) && (order.type==OP_SELL))
       {
          delete &order;
          Utils.Info("SELL Orders are not allowed");
          return NULL;
       }
       order.magic   = thrift.MagicNumber();  
       order.symbol  = Symbol;
       bool bres = false;
       if (order.type == OP_BUY)
          bres = orderHandler.Long(order.symbol, order.lots, 0, 0, order.comment);
       else 
          bres = orderHandler.Short(order.symbol, order.lots, 0, 0, order.comment);
          
       if (bres)
       {
          if (order.SelectBySymbol())
          {
             order.SetId(Utils.OrderTicket());
             order.setTakeProfit(order.TakeProfit(false));
             order.setStopLoss(order.StopLoss(false));
             Utils.Trade().ChangeOrder(order, order.StopLoss(true), order.TakeProfit(true));
             //order.updateSL(true);
             //order.updateTP(true);

             globalOrders.Fill(order);

             globalOrders.Add(&order);
             if (!Utils.IsTesting())
                SaveOrders();
                
             UpdateStopLossesTakeProfits(true);
          }
          return &order;
      }
      return NULL;
   }

   //+------------------------------------------------------------------+
   bool ChangeOrder(Order& order, double stoploss, double takeprofit)
   {
      return orderHandler.Modify(order.Id(), stoploss, takeprofit);
   }

   bool CloseOrderPartially(Order& order, double newLotSize)
   {
      if (orderHandler._IsNettingAccount())
      {
         if (order.type == OP_BUY)
         {
             return orderHandler.Short(order.symbol, newLotSize, 0, 0, order.comment);
         } else 
             return orderHandler.Long(order.symbol, newLotSize, 0, 0, order.comment);
      }
      return orderHandler.ClosePartial(order.Id(), newLotSize);
   }
   
   long searchNewTicket(long oldTicket)
   {
      for(int i=Utils.OrdersTotal()-1; i>=0; i--)
         if(Utils.SelectOrderByPos(i) &&
            StringToInteger(StringSubstr(Utils.OrderComment(),StringFind(Utils.OrderComment(),"#")+1)) == oldTicket )
            return (Utils.OrderTicket());
      return (-1);
   }
   
Order* InitManualOrder(int type) {
   Order* order = new Order(-1);
   order.type = type;
   order.SetRole(RegularTrail);
   
   order.openPrice = (type==OP_BUY)?Utils.Bid():Utils.Ask();
   order.setTakeProfit(TakeProfit(order.openPrice, order.type));
   order.setStopLoss(StopLoss(order.openPrice, order.type));

   order.lots = ContractsToLots(order.type, order.getNContracts() );
   order.comment = "Manual";
   return order;
}
   
Order* InitExpertOrder(int type) {
   Order* order = new Order(-1);
   order.type = type;
   order.SetRole(RegularTrail);
   
   order.openPrice = (type==OP_BUY)?Utils.Bid():Utils.Ask();
   order.setTakeProfit(TakeProfit(order.openPrice, order.type));
   order.setStopLoss(StopLoss(order.openPrice, order.type));
   
   order.lots = ContractsToLots(order.type, order.getNContracts() );
   order.comment = "Expert";
   return order;
}
      
Order* InitFromPending(PendingOrder* pend) {
   Order* order = new Order(pend.Id());
   order.type = pend.type;
   order.SetRole(RegularTrail);
   order.lots = pend.lots;
   order.SetNContracts(pend.getNContracts());
   order.setStopLoss(pend.StopLoss(false));
   order.setTakeProfit(pend.TakeProfit(false));
   order.comment = StringFormat("%s %s", order.TypeToString(), EnumToString(pend.Role()));
   return order;
}

Order* OpenExpertOrder(int Value, string Name) 
{
   int countOrders = CountOrdersByType(Value, Orders());
   if (countOrders > 0)
      return NULL;
   Order* order = InitExpertOrder(Value);
   order.signalName = Name;
   Order* neworder = OpenOrder(order);
   
   if (neworder != NULL)
   {
      Utils.Info(StringFormat("Order <%s> %s lots=%g Created SUCCESSFULLY", order.symbol, order.TypeToString(), order.lots));
      return neworder;
   }
   return NULL;
}
   
//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ФРАКТАЛАМ                                            |
//| Функции передаётся тикет позиции, количество баров в фрактале,   |
//| и отступ (пунктов) - расстояние от макс. (мин.) свечи, на        |
//| которое переносится стоплосс (от 0), trlinloss - тралить ли в    |
//| зоне убытков                                                     |
//+------------------------------------------------------------------+
void TrailingByFractals(Order& order, ENUM_TIMEFRAMES tmfrm,int frktl_bars,int indent,bool trlinloss)
   {
   int i, z; // counters
   int extr_n; // номер ближайшего экстремума frktl_bars-барного фрактала 
   double temp; // служебная переменная
   int after_x, be4_x; // свечей после и до пика соответственно
   int ok_be4, ok_after; // флаги соответствия условию (1 - неправильно, 0 - правильно)
   int sell_peak_n = 0, buy_peak_n = 0; // номера экстремумов ближайших фракталов на продажу (для поджатия дл.поз.) и покупку соответсвенно   
   
   // проверяем переданные значения
   if ((frktl_bars<=3) || (indent<0) || (!order.Valid()) || (!order.Select()))
   {
      Print("Трейлинг функцией TrailingByFractals() невозможен из-за некорректности значений переданных ей аргументов.");
      return ;
   } 
   
   temp = frktl_bars;
      
   if (MathMod(frktl_bars,2)==0)
   extr_n = (int)temp/2;
   else                
   extr_n = (int)MathRound(temp/2);
      
   // баров до и после экстремума фрактала
   after_x = frktl_bars - extr_n;
   if (MathMod(frktl_bars,2)!=0)
   be4_x = frktl_bars - extr_n;
   else
   be4_x = frktl_bars - extr_n - 1;    
   
   // если длинная позиция (OP_BUY), находим ближайший фрактал на продажу (т.е. экстремум "вниз")
   if (Utils.OrderType()==OP_BUY)
      {
      // находим последний фрактал на продажу
      for (i=extr_n;i<iBars(_Symbol,tmfrm);i++)
         {
         ok_be4 = 0; ok_after = 0;
         
         for (z=1;z<=be4_x;z++)
            {
            if (iLow(_Symbol,tmfrm,i)>=iLow(_Symbol,tmfrm,i-z)) 
               {
               ok_be4 = 1;
               break;
               }
            }
            
         for (z=1;z<=after_x;z++)
            {
            if (iLow(_Symbol,tmfrm,i)>iLow(_Symbol,tmfrm,i+z)) 
               {
               ok_after = 1;
               break;
               }
            }            
         
         if ((ok_be4==0) && (ok_after==0))                
            {
            sell_peak_n = i; 
            break;
            }
         }
     
      // если тралить в убытке
      if (trlinloss==true)
         {
         // если новый стоплосс лучше имеющегося (в т.ч. если стоплосс == 0, не выставлен)
         // а также если курс не слишком близко, ну и если стоплосс уже не был перемещен на рассматриваемый уровень         
         if ((iLow(_Symbol,tmfrm,sell_peak_n)-indent*_Point>Utils.OrderStopLoss()) && (iLow(_Symbol,tmfrm,sell_peak_n)-indent*_Point<Utils.Bid() - StopLevelPoints))
            {
               ChangeOrder(order,iLow(_Symbol,tmfrm,sell_peak_n)-indent*_Point,Utils.OrderTakeProfit());
            //if (!OrderModify(ticket,Utils.OrderOpenPrice(),iLow(_Symbol,tmfrm,sell_peak_n)-indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration()))
            //Print("Не удалось модифицировать стоплосс ордера №",OrderTicket(),". Ошибка: ",GetLastError());
            }
         }
      // если тралить только в профите, то
      else
         {
            // если новый стоплосс лучше имеющегося И курса открытия, а также не слишком близко к текущему курсу
            if ((iLow(_Symbol,tmfrm,sell_peak_n)-indent*_Point>Utils.OrderStopLoss()) && (iLow(_Symbol,tmfrm,sell_peak_n)-indent*_Point>Utils.OrderOpenPrice()) && (iLow(_Symbol,tmfrm,sell_peak_n)-indent*_Point<Utils.Bid()-StopLevelPoints))
            {
               ChangeOrder(order,iLow(_Symbol,tmfrm,sell_peak_n)-indent*Point,Utils.OrderTakeProfit());
               //if (!OrderModify(ticket,Utils.OrderOpenPrice(),iLow(_Symbol,tmfrm,sell_peak_n)-indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration()))
               //Print("Не удалось модифицировать стоплосс ордера №",OrderTicket(),". Ошибка: ",GetLastError());
            }
         }
      }
      
   // если короткая позиция (OP_SELL), находим ближайший фрактал на покупку (т.е. экстремум "вверх")
   if (Utils.OrderType()==OP_SELL)
      {
      // находим последний фрактал на продажу
      for (i=extr_n;i<iBars(_Symbol,tmfrm);i++)
         {
         ok_be4 = 0; ok_after = 0;
         
         for (z=1;z<=be4_x;z++)
            {
            if (iHigh(_Symbol,tmfrm,i)<=iHigh(_Symbol,tmfrm,i-z)) 
               {
               ok_be4 = 1;
               break;
               }
            }
            
         for (z=1;z<=after_x;z++)
            {
            if (iHigh(_Symbol,tmfrm,i)<iHigh(_Symbol,tmfrm,i+z)) 
               {
               ok_after = 1;
               break;
               }
            }            
         
         if ((ok_be4==0) && (ok_after==0))                
            {
            buy_peak_n = i;
            break;
            }
         }        
      
      // если тралить в убытке
      if (trlinloss==true)
         {
         if (((iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*_Point<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && (iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*_Point>Utils.Ask()+StopLevelPoints))
            {
               ChangeOrder(order,iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point,Utils.OrderTakeProfit());
            }
         }      
      // если тралить только в профите, то
      else
         {
         // если новый стоплосс лучше имеющегося И курса открытия
         if ((((iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0))) && (iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point<Utils.OrderOpenPrice()) && (iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point>Utils.Ask()+StopLevelPoints))
            {
                ChangeOrder(order,iHigh(_Symbol,tmfrm,buy_peak_n)+(indent+Utils.Spread())*_Point,Utils.OrderTakeProfit());
            }
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ТЕНЯМ N СВЕЧЕЙ                                       |
//| Функции передаётся тикет позиции, количество баров, по теням     |
//| которых необходимо трейлинговать (от 1 и больше) и отступ        |
//| (пунктов) - расстояние от макс. (мин.) свечи, на которое         |
//| переносится стоплосс (от 0), trlinloss - тралить ли в лоссе      | 
//+------------------------------------------------------------------+
void TrailingByShadows(Order& order,ENUM_TIMEFRAMES tmfrm,int bars_n, int indent,bool trlinloss)
   {  
   
   int i; // counter
   double new_extremum = 0;
   
   // проверяем переданные значения
   if ((bars_n<1) || (indent<0) || (!order.Valid()) || ((tmfrm!=1) && (tmfrm!=5) && (tmfrm!=15) && (tmfrm!=30) && (tmfrm!=60) && (tmfrm!=240) && (tmfrm!=1440) && (tmfrm!=10080) && (tmfrm!=43200)) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingByShadows() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   // если длинная позиция (OP_BUY), находим минимум bars_n свечей
   if (Utils.OrderType()==OP_BUY)
      {
      for(i=1;i<=bars_n;i++)
         {
         if (i==1) new_extremum = iLow(_Symbol,tmfrm,i);
         else 
         if (new_extremum>iLow(_Symbol,tmfrm,i)) new_extremum = iLow(_Symbol,tmfrm,i);
         }         
      
      // если тралим и в зоне убытков
      if (trlinloss == true)
         {
           // если найденное значение "лучше" текущего стоплосса позиции, переносим 
           if ((((new_extremum - indent*Point)>Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && (new_extremum - indent*Point<Utils.Bid()-StopLevelPoints))
              ChangeOrder(order, new_extremum - indent*Point,Utils.OrderTakeProfit());
         }
      else
         {
           // если новый стоплосс не только лучше предыдущего, но и курса открытия позиции
           if ((((new_extremum - indent*Point)>Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && ((new_extremum - indent*Point)>Utils.OrderOpenPrice()) && (new_extremum - indent*Point<Utils.Bid()-StopLevelPoints))
              ChangeOrder(order, new_extremum-indent*Point,Utils.OrderTakeProfit());
         }
      }
      
   // если короткая позиция (OP_SELL), находим минимум bars_n свечей
   if (Utils.OrderType()==OP_SELL)
      {
      for(i=1;i<=bars_n;i++)
         {
         if (i==1) new_extremum = iHigh(_Symbol,tmfrm,i);
         else 
         if (new_extremum<iHigh(_Symbol,tmfrm,i)) new_extremum = iHigh(_Symbol,tmfrm,i);
         }         
           
      // если тралим и в зоне убытков
      if (trlinloss==true)
         {
         // если найденное значение "лучше" текущего стоплосса позиции, переносим 
            if ((((new_extremum + (indent + Utils.Spread())*Point)<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && (new_extremum + (indent + Utils.Spread())*Point>Utils.Ask()+StopLevelPoints))
                ChangeOrder(order, new_extremum + (indent + Utils.Spread())*Point,Utils.OrderTakeProfit());
         }
      else
         {
         // если новый стоплосс не только лучше предыдущего, но и курса открытия позиции
             if ((((new_extremum + (indent + Utils.Spread())*Point)<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && ((new_extremum + (indent + Utils.Spread())*Point)<Utils.OrderOpenPrice()) && (new_extremum + (indent +  Utils.Spread())*Point>Utils.Ask()+StopLevelPoints))
                ChangeOrder(order, new_extremum + (indent + Utils.Spread())*Point,Utils.OrderTakeProfit());
         }      
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ СТАНДАРТНЫЙ-СТУПЕНЧАСТЫЙ                                |
//| Функции передаётся тикет позиции, расстояние от курса открытия,  |
//| на котором трейлинг запускается (пунктов) и "шаг", с которым он  |
//| переносится (пунктов)                                            |
//| Пример: при +30 стоп на +10, при +40 - стоп на +20 и т.д.        |
//+------------------------------------------------------------------+
void TrailingStairs(Order& order,int startDistance,int trlstep)
{ 
   double nextstair = 0;
   // if ((startDistance<Utils.StopLevel()) || (trlstep<1) || (startDistance<trlstep) || (!order.Valid()) || (!order.Select()))
   // {
   //   Utils.Info("Трейлинг функцией TrailingStairs() невозможен из-за некорректности значений переданных ей аргументов.");
   //   return;
   // }
   
   double sl = order.StopLoss(false);
   double tp = order.TakeProfit(false);
   double Spread = Utils.Spread();
   double distance = (startDistance + trlstep)*Point;
   if (order.type == OP_BUY)
   {
      double bid = Utils.Bid();
      double startLevel = order.openPrice + (startDistance + Spread) * Point;
      if ( bid > startLevel )
      {
         if ((bid - sl ) > distance)
         {
            { // Adjust real stops
               double realStop = order.StopLoss(true);
               if (realStop < order.openPrice )
               {
                  double minStop = order.openPrice + MathMax(Utils.StopLevel() * Point, (trlstep + Spread) * Point);
                  ChangeOrder(order, minStop, Utils.OrderTakeProfit());
               }
            }
            nextstair = sl + trlstep*Point;
            order.setStopLoss(nextstair);
         }                    
      }          
   }
      
   if (order.type==OP_SELL)
   { 
      double ask = Utils.Ask();
      double startLevel = order.openPrice - (startDistance + Spread)*Point;
      if ( ask  <  startLevel )
      {
         {  // Adjust read stops
            double realStop = order.StopLoss(true);
            if (realStop > order.openPrice )
            {
               double minStop = order.openPrice - MathMax(Utils.StopLevel() * Point, (trlstep + Spread) * Point);
               ChangeOrder(order, minStop, Utils.OrderTakeProfit());
            }
         }
         
         if (( sl - ask ) > distance)
         {
            nextstair = sl - trlstep*Point;
            order.setStopLoss(nextstair);
         }
      }
   }      
}


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ СТАНДАРТНЫЙ-ЗАТЯГИВАЮЩИЙСЯ                              |
//| Функции передаётся тикет позиции, исходный трейлинг (пунктов) и  |
//| 2 "уровня" (значения профита, пунктов), при которых трейлинг     |
//| сокращаем, и соответствующие значения трейлинга (пунктов)        |
//| Пример: исходный трейлинг 30 п., при +50 - 20 п., +80 и больше - |
//| на расстоянии в 10 пунктов.                                      |
//+------------------------------------------------------------------+

void TrailingUdavka(Order& order,int trl_dist_1,int level_1,int trl_dist_2,int level_2,int trl_dist_3)
   {  
   
   double newstop = 0; // новый стоплосс
   double trldist = 0; // расстояние трейлинга (в зависимости от "пройденного" может = trl_dist_1, trl_dist_2 или trl_dist_3)

   // проверяем переданные значения
   if ((trl_dist_1<Utils.StopLevel()) || (trl_dist_2<Utils.StopLevel()) || (trl_dist_3<Utils.StopLevel()) || 
   (level_1<=trl_dist_1) || (level_2<=trl_dist_1) || (level_2<=level_1) || (!order.Valid()) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingUdavka() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
        double bid = Utils.Bid();
      // если профит <=trl_dist_1, то trldist=trl_dist_1, если профит>trl_dist_1 && профит<=level_1*Point ...
      if ((bid-Utils.OrderOpenPrice())<=level_1*Point) trldist = trl_dist_1;
      if (((bid-Utils.OrderOpenPrice())>level_1*Point) && ((Utils.Bid()-Utils.OrderOpenPrice())<=level_2*Point)) trldist = trl_dist_2;
      if ((bid-Utils.OrderOpenPrice())>level_2*Point) trldist = trl_dist_3; 
            
      // если стоплосс = 0 или меньше курса открытия, то если тек.цена (Bid) больше/равна дистанции курс_открытия+расст.трейлинга
      if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice()))
         {
         if (bid>(Utils.OrderOpenPrice() + trldist*Point))
         newstop = bid -  trldist*Point;
         }

      // иначе: если текущая цена (Bid) больше/равна дистанции текущий_стоплосс+расстояние трейлинга, 
      else
         {
         if (bid>(Utils.OrderStopLoss() + trldist*Point))
         newstop = bid -  trldist*Point;
         }
      
      // модифицируем стоплосс
      if ((newstop>Utils.OrderStopLoss()) && (newstop<bid-StopLevelPoints))
         {
            ChangeOrder(order,newstop,Utils.OrderTakeProfit());
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      { 
         double ask = Utils.Ask();

      // если профит <=trl_dist_1, то trldist=trl_dist_1, если профит>trl_dist_1 && профит<=level_1*Point ...
      if ((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))<=level_1*Point) trldist = trl_dist_1;
      if (((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))>level_1*Point) && ((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))<=level_2*Point)) trldist = trl_dist_2;
      if ((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))>level_2*Point) trldist = trl_dist_3; 
            
      // если стоплосс = 0 или меньше курса открытия, то если тек.цена (Ask) больше/равна дистанции курс_открытия+расст.трейлинга
      if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice()))
         {
         if (ask<(Utils.OrderOpenPrice() - (trldist + Utils.Spread())*Point))
         newstop = ask + trldist*Point;
         }

      // иначе: если текущая цена (Bid) больше/равна дистанции текущий_стоплосс+расстояние трейлинга, 
      else
         {
         if (ask<(Utils.OrderStopLoss() - (trldist + Utils.Spread())*Point))
         newstop = ask +  trldist*Point;
         }
            
       // модифицируем стоплосс
      if (newstop>0)
         {
         if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice())) && (newstop>ask+StopLevelPoints))
            {
               ChangeOrder(order,newstop,Utils.OrderTakeProfit());
            }
         else
            {
            if ((newstop<Utils.OrderStopLoss()) && (newstop>Utils.Ask()+StopLevelPoints))  
               {
                  ChangeOrder(order,newstop,Utils.OrderTakeProfit());
               }
            }
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ВРЕМЕНИ                                              |
//| Функции передаётся тикет позиции, интервал (минут), с которым,   |
//| передвигается стоплосс и шаг трейлинга (на сколько пунктов       |
//| перемещается стоплосс, trlinloss - тралим ли в убытке            |
//| (т.е. с определённым интервалом подтягиваем стоп до курса        |
//| открытия, а потом и в профите, либо только в профите)            |
//+------------------------------------------------------------------+
void TrailingByTime(Order &order,int interval,int trlstep,bool trlinloss)
   {
      
   // проверяем переданные значения
   if ((!order.Valid()) || (interval<1) || (trlstep<1) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingByTime() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      }
      
   double minpast; // кол-во полных минут от открытия позиции до текущего момента 
   double times2change; // кол-во интервалов interval с момента открытия позиции (т.е. сколько раз должен был быть перемещен стоплосс) 
   double newstop; // новое значение стоплосса (учитывая кол-во переносов, которые должны были иметь место)
   
   // определяем, сколько времени прошло с момента открытия позиции
   minpast = (double)(TimeCurrent() - Utils.OrderOpenTime()) / 60;
      
   // сколько раз нужно было передвинуть стоплосс
   times2change = MathFloor(minpast / interval);
         
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
      // если тралим в убытке, то отступаем от стоплосса (если он не 0, если 0 - от открытия)
      if (trlinloss==true)
         {
         if (Utils.OrderStopLoss()==0) newstop =Utils.OrderOpenPrice() + times2change*(trlstep*Point);
         else newstop =Utils.OrderStopLoss() + times2change*(trlstep*Point); 
         }
      else
      // иначе - от курса открытия позиции
      newstop =Utils.OrderOpenPrice() + times2change*(trlstep*Point); 
         
      if (times2change>0)
         {
         if ((newstop>Utils.OrderStopLoss()) && (newstop<Utils.Bid()- StopLevelPoints))
            {
                ChangeOrder(order,newstop,Utils.OrderTakeProfit());
            }
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      {
      // если тралим в убытке, то отступаем от стоплосса (если он не 0, если 0 - от открытия)
      if (trlinloss==true)
         {
         if (Utils.OrderStopLoss()==0) newstop =Utils.OrderOpenPrice() - times2change*(trlstep*Point) - Utils.Spread()*Point;
         else newstop =Utils.OrderStopLoss() - times2change*(trlstep*Point) - Utils.Spread()*Point;
         }
      else
      newstop =Utils.OrderOpenPrice() - times2change*(trlstep*Point) - Utils.Spread()*Point;
                
      if (times2change>0)
         {
         if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice())) && (newstop>Utils.Ask()+StopLevelPoints))
            {
                ChangeOrder(order,newstop,Utils.OrderTakeProfit());
            }
         else
         if ((newstop<Utils.OrderStopLoss()) && (newstop>Utils.Ask()+StopLevelPoints))
            {
                ChangeOrder(order,newstop,Utils.OrderTakeProfit());
            }
         }
      }      
   }
//+------------------------------------------------------------------+

void TrailEachNewBar(Order& order, ENUM_TIMEFRAMES tf)
{
   if ((!order.Valid()) || (!order.Select())  )
   {
      Print("Трейлинг функцией TrailingByATR() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
   }
   double sl = DefaultStopLoss();
   double tp = DefaultTakeProfit();
   double ask = Utils.Ask();
   double bid = Utils.Bid();
   double OP = Utils.OrderOpenPrice();

   if (order.type==OP_BUY)
   {
      // откладываем от текущего курса (новый стоплосс)
      sl = OP - sl*Point;
      tp = OP + tp*Point;  
   }
   if (order.type==OP_SELL)
   {
      sl = OP + sl*Point;
      tp = OP - tp*Point;  
   }

   ChangeOrder(order, sl,tp);
}

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ATR (Average True Range, Средний истинный диапазон)  |
//| Функции передаётся тикет позиции, период АТR и коэффициент, на   |
//| который умножается ATR. Т.о. стоплосс "тянется" на расстоянии    |
//| ATR х N от текущего курса; перенос - на новом баре (т.е. от цены |
//| открытия очередного бара) coeffSL = 2, coeffTP =3                |
//+------------------------------------------------------------------+
void TrailingByATR(Order& order,int atr_timeframe, int atr_shift, double coeffSL, double coeffTP,bool trlinloss)
{
   // проверяем переданные значения   
   if ((!order.Valid()) || (!order.Select()) || (atr_shift<0) )
      {
      Print("Трейлинг функцией TrailingByATR() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      }
   
   double curr_atr; // текущее значение ATR - 1
   //double curr_atr2; // текущее значение ATR - 2
   double best_atr; // большее из значений ATR
   double atrXcoeffSL, atrXcoeffTP; // результат умножения большего из ATR на коэффициент
   double newstop; // новый стоплосс
   double newtp;
   
   // текущее значение ATR-1, ATR-2
   curr_atr = signals.GetATR(atr_shift);
   //curr_atr2 = Utils.iATR((ENUM_TIMEFRAMES)atr_timeframe,atr2_period,atr2_shift);
   
   // большее из значений
   best_atr = curr_atr;//MathMax(curr_atr1,curr_atr2);
   
   // после умножения на коэффициент
   atrXcoeffSL = best_atr * coeffSL;
   atrXcoeffTP = best_atr * coeffTP;
   
   double ask = Utils.tick.ask;
   double bid = Utils.tick.bid;
              
   // если длинная позиция (OP_BUY)
   if (order.type==OP_BUY)
      {
      // откладываем от текущего курса (новый стоплосс)
      newstop = bid - atrXcoeffSL;
      newtp = ask + atrXcoeffTP;  
               
      // если trlinloss==true (т.е. следует тралить в зоне лоссов), то
      if (trlinloss==true)      
         {
         // если стоплосс неопределен, то тралим в любом случае
         if ((Utils.OrderStopLoss()==0) && (newstop<bid-StopLevelPoints))
            {
               ChangeOrder(order, newstop,newtp);
            }
         // иначе тралим только если новый стоп лучше старого
         else
            {
            if ((newstop>Utils.OrderStopLoss()) && (newstop<bid-StopLevelPoints))
               ChangeOrder(order,newstop,newtp);
            }
         }
      else
         {
         // если стоплосс неопределен, то тралим, если стоп лучше открытия
         if ((Utils.OrderStopLoss()==0) && (newstop>Utils.OrderOpenPrice()) && (newstop<bid-StopLevelPoints))
            {
               ChangeOrder(order,newstop,newtp);
            }
         // если стоп не равен 0, то меняем его, если он лучше предыдущего и курса открытия
         else
            {
            if ((newstop>Utils.OrderStopLoss()) && (newstop>Utils.OrderOpenPrice()) && (newstop<bid-StopLevelPoints))
               ChangeOrder(order,newstop,newtp);
               //if (!OrderModify(ticket,Utils.OrderOpenPrice(),newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration()))
               //Print("Не удалось модифицировать ордер №",OrderTicket(),". Ошибка: ",GetLastError());
            }
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (order.type==OP_SELL)
      {
      // откладываем от текущего курса (новый стоплосс)
      newstop = ask + atrXcoeffSL;
      newtp = bid - atrXcoeffTP;
      
      // если trlinloss==true (т.е. следует тралить в зоне лоссов), то
      if (trlinloss==true)      
         {
         // если стоплосс неопределен, то тралим в любом случае
         if ((Utils.OrderStopLoss()==0) && (newstop>ask+StopLevelPoints))
            {
               ChangeOrder(order,newstop,newtp);
            }
         // иначе тралим только если новый стоп лучше старого
         else
            {
            if ((newstop<Utils.OrderStopLoss()) && (newstop>ask+StopLevelPoints))
               ChangeOrder(order,newstop,newtp);
            }
         }
      else
         {
         // если стоплосс неопределен, то тралим, если стоп лучше открытия
         if ((Utils.OrderStopLoss()==0) && (newstop<Utils.OrderOpenPrice()) && (newstop>ask+StopLevelPoints))
            {
               ChangeOrder(order,newstop,newtp);
            }
         // если стоп не равен 0, то меняем его, если он лучше предыдущего и курса открытия
         else
            {
            if ((newstop<Utils.OrderStopLoss()) && (newstop<Utils.OrderOpenPrice()) && (newstop>ask+StopLevelPoints))
               ChangeOrder(order,newstop,newtp);
            }
         }
      }      
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ЦЕНВОМУ КАНАЛУ                                       |
//| Функции передаётся тикет позиции, период (кол-во баров) для      | 
//| рассчета верхней и нижней границ канала, отступ (пунктов), на    |
//| котором размещается стоплосс от границы канала                   |
//| Трейлинг по закрывшимся барам.                                   |
//+------------------------------------------------------------------+
void TrailingByPriceChannel(Order& order,int iBars_n,int iIndent)
   {     
   
   // проверяем переданные значения
   if ((iBars_n<1) || (iIndent<0) || (!order.Valid()) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingByPriceChannel() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   double   dChnl_max; // верхняя граница канала
   double   dChnl_min; // нижняя граница канала
   
   // определяем макс.хай и мин.лоу за iBars_n баров начиная с [1] (= верхняя и нижняя границы ценового канала)
   dChnl_max = iHigh(Symbol, _Period, iHighest(_Symbol,0,2,iBars_n,1)) + (iIndent+Utils.Spread())*Point;
   dChnl_min = iLow(Symbol, _Period, iLowest(_Symbol,0,1,iBars_n,1)) - iIndent*Point;   
   
   // если длинная позиция, и её стоплосс хуже (ниже нижней границы канала либо не определен, ==0), модифицируем его
   if (order.type == OP_BUY)
      {
      if ((Utils.OrderStopLoss()<dChnl_min) && (dChnl_min<Utils.Bid()-StopLevelPoints))
         {
            //if (MaxStopLoss != 0)
            //   dChnl_min = MathMax(Bid - MaxStopLoss * Point, dChnl_min);
            //double TP = OrderTakeProfit();
            //if (MaxTakeProfit != 0)
            //   TP = Ask + MaxTakeProfit* Point;
            ChangeOrder(order,dChnl_min,Utils.OrderTakeProfit());
         }
      }
   
   // если позиция - короткая, и её стоплосс хуже (выше верхней границы канала или не определён, ==0), модифицируем его
   if (order.type == OP_SELL)
      {
      if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>dChnl_max)) && (dChnl_min>Utils.Ask()+StopLevelPoints))
         {
            //if (MaxStopLoss != 0)
            //   dChnl_max = MathMin(Ask + MaxStopLoss * Point, dChnl_max);
            //double TP = OrderTakeProfit();
            //if (MaxTakeProfit != 0)
            //  TP = Bid - MaxTakeProfit* Point;
            ChangeOrder(order,dChnl_max,Utils.OrderTakeProfit());
         }
      }
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО СКОЛЬЗЯЩЕМУ СРЕДНЕМУ                                 |
//| Функции передаётся тикет позиции и параметры средней (таймфрейм, | 
//| период, тип, сдвиг относительно графика, метод сглаживания,      |
//| составляющая OHCL для построения, № бара, на котором берется     |
//| значение средней.                                                |
//+------------------------------------------------------------------+

//    Допустимые варианты ввода:   
//    iTmFrme:    1 (M1), 5 (M5), 15 (M15), 30 (M30), 60 (H1), 240 (H4), 1440 (D), 10080 (W), 43200 (MN);
//    iMAPeriod:  2-infinity, целые числа; 
//    iMAShift:   целые положительные или отрицательные числа, а также 0;
//    MAMethod:   0 (MODE_SMA), 1 (MODE_EMA), 2 (MODE_SMMA), 3 (MODE_LWMA);
//    iApplPrice: 0 (PRICE_CLOSE), 1 (PRICE_OPEN), 2 (PRICE_HIGH), 3 (PRICE_LOW), 4 (PRICE_MEDIAN), 5 (PRICE_TYPICAL), 6 (PRICE_WEIGHTED)
//    iShift:     0-Bars, целые числа;
//    iIndent:    0-infinity, целые числа;

void TrailingByMA(Order& order,int iTmFrme,int iMAPeriod,int iMAShift,int MAMethod,int iApplPrice,int iShift,int iIndent)
   {     
   
   // проверяем переданные значения
   if ((!order.Valid()) || (!order.Select()) || ((iTmFrme!=1) && (iTmFrme!=5) && (iTmFrme!=15) && (iTmFrme!=30) && (iTmFrme!=60) && (iTmFrme!=240) && (iTmFrme!=1440) && (iTmFrme!=10080) && (iTmFrme!=43200)) ||
   (iMAPeriod<2) || (MAMethod<0) || (MAMethod>3) || (iApplPrice<0) || (iApplPrice>6) || (iShift<0) || (iIndent<0))
      {
      Print("Трейлинг функцией TrailingByMA() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 

   double   dMA; // значение скользящего среднего с переданными параметрами
   
   // определим значение МА с переданными функции параметрами
   dMA = Utils.iMA((ENUM_TIMEFRAMES)iTmFrme,iMAPeriod,iMAShift,(ENUM_MA_METHOD)MAMethod,(ENUM_APPLIED_PRICE)iApplPrice,iShift);
         
   // если длинная позиция, и её стоплосс хуже значения среднего с отступом в iIndent пунктов, модифицируем его
   if (Utils.OrderType()==OP_BUY)
      {
      if ((Utils.OrderStopLoss()<dMA-iIndent*Point) && (dMA-iIndent*Point<Utils.Bid()-StopLevelPoints))
         {
            ChangeOrder(order,dMA-iIndent*Point,Utils.OrderTakeProfit());
         }
      }
   
   // если позиция - короткая, и её стоплосс хуже (выше верхней границы канала или не определён, ==0), модифицируем его
   if (Utils.OrderType()==OP_SELL)
      {
      if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>dMA+(Utils.Spread()+iIndent)*Point)) && (dMA+(Utils.Spread()+iIndent)*Point>Utils.Ask()+StopLevelPoints))
         {
            ChangeOrder(order,dMA+(Utils.Spread()+iIndent)*Point,Utils.OrderTakeProfit());
         }
      }
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ "ПОЛОВИНЯЩИЙ"                                           |
//| По закрытии очередного периода (бара) подтягиваем стоплосс на    |
//| половину (но можно и любой иной коэффициент) дистанции, прой-    |
//| денной курсом (т.е., например, по закрытии суток профит +55 п. - |
//| стоплосс переносим в 55/2=27 п. Если по закрытии след.           |
//| суток профит достиг, допустим, +80 п., то стоплосс переносим на  |
//| половину (напр.) расстояния между тек. стоплоссом и курсом на    |
//| закрытии бара - 27 + (80-27)/2 = 27 + 53/2 = 27 + 26 = 53 п.     |
//| iTicket - тикет позиции; iTmFrme - таймфрейм (в минутах, цифрами |
//| dCoeff - "коэффициент поджатия", в % от 0.01 до 1 (в последнем   |
//| случае стоплосс будет перенесен (если получится) вплотную к тек. |
//| курсу и позиция, скорее всего, сразу же закроется)               |
//| bTrlinloss - стоит ли тралить на лоссовом участке - если да, то  |
//| по закрытию очередного бара расстояние между стоплоссом (в т.ч.  |
//| "до" безубытка) и текущим курсом будет сокращаться в dCoeff раз  |
//| чтобы посл. вариант работал, обязательно должен быть определён   |
//| стоплосс (не равен 0)                                            |
//+------------------------------------------------------------------+

void TrailingFiftyFifty(Order& order,ENUM_TIMEFRAMES iTmFrme,double dCoeff,bool bTrlinloss)
   { 
   // активируем трейлинг только по закрытии бара
   if (sdtPrevtime == iTime(_Symbol, iTmFrme,0)) 
      return;
   else
      {
      sdtPrevtime = iTime(_Symbol, iTmFrme,0);             
      
      // проверяем переданные значения
      if ((!order.Valid()) || (!order.Select()) || 
      ((iTmFrme!=1) && (iTmFrme!=5) && (iTmFrme!=15) && (iTmFrme!=30) && (iTmFrme!=60) && (iTmFrme!=240) && 
      (iTmFrme!=1440) && (iTmFrme!=10080) && (iTmFrme!=43200)) || (dCoeff<0.01) || (dCoeff>1.0))
         {
         Print("Трейлинг функцией TrailingFiftyFifty() невозможен из-за некорректности значений переданных ей аргументов.");
         return;
         }
         
      // начинаем тралить - с первого бара после открывающего (иначе при bTrlinloss сразу же после открытия 
      // позиции стоплосс будет перенесен на половину расстояния между стоплоссом и курсом открытия)
      // т.е. работаем только при условии, что с момента OrderOpenTime() прошло не менее iTmFrme минут
      if (iTime(_Symbol, iTmFrme,0)>Utils.OrderOpenTime())
      {         
      
      double dBid = Utils.Bid();
      double dAsk = Utils.Ask();
      double dNewSl = 0;
      double dNexMove = 0;     
      
      // для длинной позиции переносим стоплосс на dCoeff дистанции от курса открытия до Bid на момент открытия бара
      // (если такой стоплосс лучше имеющегося и изменяет стоплосс в сторону профита)
      if (Utils.OrderType()==OP_BUY)
         {
         if ((bTrlinloss) && (Utils.OrderStopLoss()!=0))
            {
            dNexMove = NormalizeDouble(dCoeff*(dBid-Utils.OrderStopLoss()),Digits);
            dNewSl = NormalizeDouble(Utils.OrderStopLoss()+dNexMove,Digits);            
            }
         else
            {
            // если стоплосс ниже курса открытия, то тралим "от курса открытия"
            if (Utils.OrderOpenPrice()>Utils.OrderStopLoss())
               {
               dNexMove = NormalizeDouble(dCoeff*(dBid-Utils.OrderOpenPrice()),Digits);                 
               //Print("dNexMove = ",dCoeff,"*(",dBid,"-",Utils.OrderOpenPrice(),")");
               dNewSl = NormalizeDouble(Utils.OrderOpenPrice()+dNexMove,Digits);
               //Print("dNewSl = ",Utils.OrderOpenPrice(),"+",dNexMove);
               }
         
            // если стоплосс выше курса открытия, тралим от стоплосса
            if (Utils.OrderStopLoss()>=Utils.OrderOpenPrice())
               {
               dNexMove = NormalizeDouble(dCoeff*(dBid-Utils.OrderStopLoss()),Digits);
               dNewSl = NormalizeDouble(Utils.OrderStopLoss()+dNexMove,Digits);
               }                                      
            }
            
         // стоплосс перемещаем только в случае, если новый стоплосс лучше текущего и если смещение - в сторону профита
         // (при первом поджатии, от курса открытия, новый стоплосс может быть лучше имеющегося, и в то же время ниже 
         // курса открытия (если dBid ниже последнего) 
         if ((dNewSl>Utils.OrderStopLoss()) && (dNexMove>0) && ((dNewSl<dBid- StopLevelPoints)))
            {
               ChangeOrder(order,dNewSl,Utils.OrderTakeProfit());
            }
         }       
      
      // действия для короткой позиции   
      if (Utils.OrderType()==OP_SELL)
         {
         if ((bTrlinloss) && (Utils.OrderStopLoss()!=0))
            {
            dNexMove = NormalizeDouble(dCoeff*(Utils.OrderStopLoss()-(dAsk+Utils.Spread()*Point)),Digits);
            dNewSl = NormalizeDouble(Utils.OrderStopLoss()-dNexMove,Digits);            
            }
         else
            {         
            // если стоплосс выше курса открытия, то тралим "от курса открытия"
            if (Utils.OrderOpenPrice()<Utils.OrderStopLoss())
               {
               dNexMove = NormalizeDouble(dCoeff*(Utils.OrderOpenPrice()-(dAsk+Utils.Spread()*Point)),Digits);                 
               dNewSl = NormalizeDouble(Utils.OrderOpenPrice()-dNexMove,Digits);
               }
         
            // если стоплосс нижу курса открытия, тралим от стоплосса
            if (Utils.OrderStopLoss()<=Utils.OrderOpenPrice())
               {
               dNexMove = NormalizeDouble(dCoeff*(Utils.OrderStopLoss()-(dAsk+Utils.Spread()*Point)),Digits);
               dNewSl = NormalizeDouble(Utils.OrderStopLoss()-dNexMove,Digits);
               }                  
            }
         
         // стоплосс перемещаем только в случае, если новый стоплосс лучше текущего и если смещение - в сторону профита
         if ((dNewSl<Utils.OrderStopLoss()) && (dNexMove>0) && (dNewSl>dAsk+StopLevelPoints))
            {
               ChangeOrder(order,dNewSl,Utils.OrderTakeProfit());
            }
         }               
      }
      }   
   }
//+------------------------------------------------------------------+

};

