//+------------------------------------------------------------------+
//|                                                 TradePanel.mqh   |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <XTrade\IUtils.mqh>
#include <XTrade\PanelBase.mqh>
#include <XTrade\ClassRow.mqh>
#include <XTrade\ITradeService.mqh>
#include <XTrade\ITrade.mqh>
#include <XTrade\OrderPanel.mqh>
#include <XTrade\InputTypes.mqh>

class TradeExpert;
class OrderPanel;  // forward declaration
//+------------------------------------------------------------------+
//| класс TradePanel 
//+------------------------------------------------------------------+
class TradePanel : public PanelBase
{
protected:
   ITradeService*     thrift;
   void              OpenOrderPanel(string UIName);
   string            GetBuildDate();
   string            buildDate;
public:
   OrderPanel*       orderPanel;
   string            EAString;
   string            MarketInfoString;   
   string            ExpertInfoString;
   string            SentiString;
   string            OrdersString;
   bool              bHideAll, bHideOrders; // bHideNews
   bool              bShowSentiments;

   //---
   CRowType1         str1EA;       // объявление строки класса
   CRowType2         str2Spread;       // объявление строки класса
   CRowType2         str3Expert;       // объявление строки класса
   CRowType2         str4Senti;       // объявление строки класса
   CRowType1         str6Orders;       // объявление строки класса
   CRowTypeOrder*    strOrders[];
   
   double SentiLongPos;
   double SentiShortPos;
   TradeExpert* expert;
   
   TradePanel(TradeExpert* ex) 
    :PanelBase(ChartID(), 0)
    ,str1EA(GetPointer(this))
    ,str2Spread(GetPointer(this))
    ,str3Expert(GetPointer(this))
    ,str4Senti(GetPointer(this))
    ,str6Orders(GetPointer(this))
   {
      expert = ex;
      bShowSentiments = false;
      thrift = Utils.Service();
      //methods = metod;
      EAString = StringFormat("%s %d", thrift.Name(), thrift.MagicNumber());
            
      MarketInfoString = "Initial Market Info";
      ExpertInfoString = "Expert:";
      SentiString = "Initial Sentiments";
      OrdersString = "Orders";
      
      //if (GET(EnableRenko))
      //   bHideAll = false;
      //else    
         bHideAll = true;
      //bHideNews = true;
      bHideOrders = false;
      
      SentiLongPos = -1;
      SentiShortPos = -1;
      
   }
   
   static Order* OrderFromUIString(string name);

   void ~TradePanel() 
   {
      if (orderPanel != NULL)
      {
         delete orderPanel;
         orderPanel = NULL;
      }
      
      for (int i = 0; i < ArraySize(strOrders);i++) 
      {
         strOrders[i].Delete();
         DELETE_PTR(strOrders[i]);
      }      
      
      //--- деинициализация главного модуля (удаляем весь мусор)
      // delete all UI data
      // ObjectsDeleteAll(chartID,subWin,-1);
   }

   void              Init();           // метод запуска главного модуля
   virtual void      OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam);
   virtual void              Draw();
   virtual void              ShowHide(string str);
      
   //--------------------------------------------------------------------
   //+------------------------------------------------------------------+
   void UpdateShowMarketInfo()
   {
      double spread = Utils.Spread();
      if (Digits() == 5 || Digits() == 3)
      {
         spread = spread / 10;
      }
      
      MarketInfoString = StringFormat("DIG=%d SPR=%s ATR(%d)=%d PT=%f SLEVEL=%d", Digits(), DoubleToString(spread, 2), 
      GET(NumBarsToAnalyze), Utils.Trade().GetDailyATR(), Point(), Utils.StopLevel() );
   }
   
   void UpdateExpertInfo()
   {
      string master = thrift.IsMaster()?"Master":"Slave";
      string active = thrift.IsActive()?"Active":"Offline";
      string renko = "";
      if (GET(EnableRenko))
      {
         int retracePercent = int(GET(retraceFactor)*100.0);
         renko = "Renko=" + IntegerToString(retracePercent) + "%";
      }
      ExpertInfoString = StringFormat("Brick=%d %s %s %s LOTS=%g LOTB=%g", GET(BrickSize), renko, master, active, 
        GET(LotsSELL), GET(LotsBUY));
   }

   /*
   string labelEventString;
   void CreateTextLabel(string msg, int Importance, datetime raisetime) 
   {
      if (StringCompare(labelEventString, msg) ==0)
            return;
      labelEventString = msg;
      Print( " Upcoming: " + msg );
      if (!Utils.IsTesting() || Utils.IsVisualMode()) {
         string name = StringFormat("newsevent%d", MathRand());
         ObjectCreate(name,OBJ_TEXT,0,raisetime,High[0]);
         ObjectSetString(0, name,OBJPROP_TEXT,msg);
         ObjectSet(name,OBJPROP_ANGLE,90);
         color clr = clrNONE;
         switch(Importance) {
             case -1:
             case 1:
             clr = clrOrange;
             break;
             case -2:
             case 2:
             clr = clrRed;
             break;
             default:
                clr = clrGray;
             break;
         }
         ObjectSet(name,OBJPROP_COLOR,clr);
      }
   }*/

};

//+------------------------------------------------------------------+
//| Метод Run класса TradePanel                                      |
//+------------------------------------------------------------------+
void TradePanel::Init()
{
   //ObjectsDeleteAll(chartID,subWin,-1);
   //--- создаём главное окно и запускаем исполняемый модуль
   if (GET(PanelSize) == PanelNormal)
   {
      Property.H = 28; // height of fonts
      SetWin(5,25,1000,CORNER_LEFT_UPPER);
   } else if (GET(PanelSize) == PanelSmall)
            {
               Property.H = 26; // height of fonts
               // X, Y positions of the Panel on the chart
               SetWin(5,20,700,CORNER_LEFT_UPPER);
            }
   str1EA.Property=Property; 
   str2Spread.Property=Property;
   str3Expert.Property=Property;
   str4Senti.Property=Property;
   str6Orders.Property=Property;
         
   ArrayResize(strOrders, MaxOpenedTrades);
   for (int i = 0; i < ArraySize(strOrders);i++) 
   {
      strOrders[i] = new CRowTypeOrder(GetPointer(this));
   }      
         
   bForceRedraw = true;
   
   buildDate = GetBuildDate();
   Draw();
}

string TradePanel::GetBuildDate() {
   //string path = MQLInfoString(MQL_PROGRAM_PATH);
   //int handle = FileOpen(path, FILE_SHARE_READ | FILE_BIN );
   //long result = FileGetInteger(handle, FILE_MODIFY_DATE);
   //if (result == -1)
   //    return "error get build date";
   //datetime dat = (datetime)result;
   //FileClose(handle);
   
   return TimeToString(__DATETIME__);
}

//+------------------------------------------------------------------+
//| Метод Draw                                            
//+------------------------------------------------------------------+
void TradePanel::Draw()
{
   if (!bForceRedraw)
   {
      if (!AllowRedrawByEvenMinutesTimer(Symbol(), (ENUM_TIMEFRAMES)GET(RefreshTimeFrame)))
         return;
   }
   bForceRedraw = false;
      
   UpdateShowMarketInfo();
   UpdateExpertInfo();
   Utils.Service().ProcessSignals();
   Utils.Trade().UpdateStopLossesTakeProfits(false);
   //Utils.Service().DealsHistory(1);
   // Add here notifications to server
   // thrift.NotifyUpdatePositions();
   
   int X,Y,B;
   X=w_xpos;
   Y=w_ypos;
   B=w_bsize;
   
   str1EA.Draw("Expert", X, Y, B, 0, EAString + ": built " + buildDate);
   Y=Y+Property.H+DELTA;
   if (bHideAll == false)
   {
      str2Spread.Edit.SetText(MarketInfoString);
      str2Spread.Draw("MarketInfo0", X, Y, B, 150, "Market Info");
      Y=Y+Property.H+DELTA;
      str3Expert.Edit.SetText(ExpertInfoString);
      str3Expert.Draw("Trend0", X, Y, B, 100, "Expert");
      Y=Y+Property.H+DELTA;
      if (bShowSentiments)
      {
         str4Senti.Edit.SetText(SentiString);      
         str4Senti.Draw("Sentiments0", X, Y, B, 150, "Sentiments");
         Y=Y+Property.H+DELTA;
      }
      
      str6Orders.Draw("Orders0", X, Y, B, 0, OrdersString);
      if (bHideOrders == false)
      {
         OrderSelection* orders = Utils.Trade().Orders();
         
         for (int i = 0; i < ArraySize(strOrders);i++) 
         {
            strOrders[i].Delete();
         }

         string ordersName = "";
         int i = 0;
         FOREACH_ORDER(orders)
         {
            strOrders[i].Property = Property;
            ordersName = StringFormat("Order_%d", order.Id());
            Y=Y+Property.H+DELTA;
            string orderStr = order.ToString();
            strOrders[i].Text.SetText(orderStr);
            strOrders[i].Draw(ordersName, X, Y, B, orderStr);
            i++;
         }
      }
   }   
   ChartRedraw(chartID);
   on_event=true;   // разрешаем обработку событий
}

Order* TradePanel::OrderFromUIString(string name) {
   ushort u_sep = StringGetCharacter("_",0);
   string result[];
   StringSplit(name, u_sep, result);
   Order* order = NULL;
   if (ArraySize(result) >= 2)
   {
      int ticket = (int)StringToInteger(result[1]);
      return order = Utils.Trade().Orders().SearchOrder(ticket);
   }
   return NULL;
}

void TradePanel::OpenOrderPanel(string UIName)
{
   ushort u_sep = StringGetCharacter("_",0);
   string result[];
   StringSplit(UIName, u_sep, result);
   Order* order = NULL;
   if (ArraySize(result) >= 2)
   {
      int ticket = (int)StringToInteger(result[1]);
      order = Utils.Trade().Orders().SearchOrder(ticket);
   }
   
   if (orderPanel == NULL)
   {
      orderPanel = new OrderPanel(order, &this);
      orderPanel.Init();
   }
   orderPanel.Draw();   
}


//+------------------------------------------------------------------+
//| Метод обработки события OnChartEvent класса TradePanel           |
//+------------------------------------------------------------------+
void TradePanel::OnEvent(const int id,
                           const long &lparam,
                           const double &dparam,
                           const string &sparam)
{

   if(on_event)
     {         
      
      if(id==CHARTEVENT_CHART_CHANGE)
      {
         SetForceRedraw();
      }
      //--- трансляция событий OnChartEvent
      str1EA.OnEvent(id,lparam,dparam,sparam);
      if (bHideAll == false)
      {
         str2Spread.OnEvent(id,lparam,dparam,sparam);
         str3Expert.OnEvent(id,lparam,dparam,sparam);
         if (bShowSentiments)
            str4Senti.OnEvent(id,lparam,dparam,sparam);
         str6Orders.OnEvent(id,lparam,dparam,sparam);
         if ( bHideOrders == false)
         {
            for (int i = 0; i < ArraySize(strOrders); i++ ) 
            {
               strOrders[i].OnEvent(id,lparam,dparam,sparam);
            }
         }
      }
      
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
            && StringFind(sparam,"Expert",0)==0)
      {
         expert.ResetChartPos();
      }
              
      //--- нажатие кнопки Close в главном окне
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".Button1",0)>0)
        {
         //--- реакция на планируемое событие
         //ExpertRemove();
        }
      //--- нажатие кнопки Hide в главном окне
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".Button0",0)>0)
        {
           ShowHide(sparam);
           return;
            //--- реакция на планируемое событие
        }
        
        //--- редактирование переменных [NEW3] : кнопка Plus STR3
        if ((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK)
        {
            if (StringFind(sparam, str6Orders.name) >= 0)
            {
                  OpenOrderPanel(sparam);
                  return;
            }
            if ((StringFind(sparam, "Order_") >= 0))
            {
               string plus = ".RowType3.Button3";
               string minus = ".RowType3.Button4";
               if (StringFind(sparam, plus) >= 0)
               {
                  OpenOrderPanel(sparam);
                  return;
               }
               if (StringFind(sparam, minus) >= 0)
               {
                  Order * order = OrderFromUIString(sparam);
                  if (order != NULL)
                  {
                     order.doSelect(true);
                     ChartRedraw(chartID);
                  }
                  return;
               }
            }
        }
        
        if (orderPanel != NULL)
           orderPanel.OnEvent(id, lparam, dparam, sparam);

     }          
}

void TradePanel::ShowHide(string sparam) {
  if (StringFind(sparam, str1EA.name) >= 0)
  {
     bHideAll = !bHideAll;
     if (bHideAll)
     {
        str2Spread.Delete();
        str3Expert.Delete();
        if (bShowSentiments)
            str4Senti.Delete();
         str6Orders.Delete();
         for (int i=0; i < ArraySize(strOrders);i++) 
         {
            strOrders[i].Delete();
         }
     }
  }
   
      
  if (StringFind(sparam, str6Orders.name)>=0)
  {
      bHideOrders = !bHideOrders;
      if (bHideOrders)
      {
         for (int i=0; i < ArraySize(strOrders);i++) 
         {
            strOrders[i].Delete();
         }
      }
  }
  SetForceRedraw();    
  Draw();           
}

