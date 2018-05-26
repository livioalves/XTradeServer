//+------------------------------------------------------------------+
//|                                                 ThriftClient.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

//--- Подключаем файлы классов
#include <ClassRow.mqh>
#include <ThriftClient.mqh>
#include <TradeMethods.mqh>

//+------------------------------------------------------------------+
//| класс TradePanel (Главный модуль)                            |
//+------------------------------------------------------------------+
class TradePanel 
{
protected:
   bool              on_event;   // флаг обработки событий

   long              Y_hide;          // величина сдвига окна
   long              Y_obj;           // величина сдвига окна
   long              H_obj;           // величина сдвига окна
   string            EAFileName;
   ThriftClient*     thrift;
   void              SetXY(int m_corner);// Метод расчёта координат
   datetime          RaiseTime; //Timer raise time
   bool              bForceRedraw;
   TradeMethods*     methods;
   
public:
   string            EAString;
   string            MarketInfoString;   
   string            TrendString;
   string            NewsStatString;
   string            NewsString;
   string            SentiString;
   string            OrdersString;
   bool              bHideAll, bHideNews, bHideOrders;

   int               w_corner;   // угол привязки
   int               w_xdelta;   // вертикальный отступ
   int               w_ydelta;   // горизонтальный отступ
   int               w_xpos;     // координата X точки привязки
   int               w_ypos;     // координата Y точки привязки
   int               w_bsize;    // ширина окна
   int               w_hsize;    // высота окна
   int               w_h_corner; // угол привязки HIDE режима
   WinCell           Property;   // свойства окна

   //---
   CRowType1         str1EA;       // объявление строки класса
   CRowType2         str2Spread;       // объявление строки класса
   CRowType2         str3Trend;       // объявление строки класса
   CRowType2         str4Senti;       // объявление строки класса
   CRowType1         str5News;       // объявление строки класса
   CRowType2         strNews[];
   CRowType1         str6Orders;       // объявление строки класса
   CRowType3         strOrders[];

   double SentiLongPos;
   double SentiShortPos;

   void TradePanel(string eaname, ThriftClient* th, TradeMethods* metod) 
   {
      EAString = eaname;
      EAFileName = eaname + ".exp";
      thrift = th;
      methods = metod;
      
      Property.TextColor=clrWhite;
      Property.BGColor=clrSteelBlue;
      Property.BGEditColor=clrDimGray;
      Property.Corner=CORNER_LEFT_UPPER;
      Property.Corn=1;
      Property.H=22;
      
      MarketInfoString = "Initial Market Info";
      TrendString = "Initial Trend";
      NewsString = "Initial News";
      SentiString = "Initial Sentiments";
      NewsStatString = "News";
      OrdersString = "Orders";
      
      bHideAll = false;
      bHideNews = false;
      bHideOrders = false;
      
      on_event = false;
      
      SentiLongPos = -1;
      SentiShortPos = -1;
      
      RaiseTime = 0;
   }
   
   void ~TradePanel() 
   {
      /*
      str1EA.Delete();
      str2Spread.Delete();       // объявление строки класса
      str3Trend.Delete();       // объявление строки класса
      str4Senti.Delete();       // объявление строки класса
      str5News.Delete();       // объявление строки класса

      for (int i=0; i < ArraySize(strNews);i++) 
      {
         strNews[i].Delete();
      }
      
      str6Orders.Delete();       // объявление строки класса

      for (int i=0; i < ArraySize(strOrders);i++) 
      {
         strOrders[i].Delete();
      }
      */

      //--- деинициализация главного модуля (удаляем весь мусор)
      // delete all UI data
      ObjectsDeleteAll(0,0,-1); 
      
   }

   void              Init();           // метод запуска главного модуля
   void              Hide();          // метод: свернуть окно
   virtual void      OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam);
   void              SetWin(int m_xdelta,
                             int m_ydelta,
                             int m_bsize,
                             int m_corner);
   void              Draw();
   
   bool AllowRedrawByEvenMinutesTimer()
   {
      datetime curtime = iTime( NULL, PERIOD_M1, 0 );

      //datetime curtime = Time[0];
      if (RaiseTime == curtime)
         return false;
      int minute = TimeMinute(curtime);
      if ( minute%2 == 0)
      {
          RaiseTime = curtime;
          return true;
      }
      return false;
   }
   
   void SetForceRedraw()
   {
       bForceRedraw = true;
   }
   
   //--------------------------------------------------------------------
   void UpdateShowGlobalSentiments()  
   {
      string symbolName = Symbol();
      double longVal = -1;
      double shortVal = -1;
      if (thrift.GetCurrentSentiments(symbolName, longVal, shortVal) != 0)
      {
         SentiLongPos = NormalizeDouble(longVal, 2);
         SentiShortPos = NormalizeDouble(shortVal, 2);
      }   
      SentiString = StringFormat("%s : Buying (%s) Selling (%s)", symbolName, DoubleToString(SentiLongPos, 2), DoubleToString(SentiShortPos, 2));
   }
   
   //+------------------------------------------------------------------+
   void UpdateShowMarketInfo()
   {
      double spread = MarketInfo(Symbol(), MODE_SPREAD);
      if (Digits == 5 || Digits == 3)
      {
         spread = spread / 10;
      }
      MarketInfoString = StringFormat("Digits (%d) Spread(%s) StopLevel(%d) Point(%f)", Digits, DoubleToStr(spread, 2), 
            MarketInfo(Symbol(), MODE_STOPLEVEL), Point );
   }

   string labelEventString;
   void CreateTextLabel(string msg, int Importance, datetime raisetime) 
   {
      if (StringCompare(labelEventString, msg) ==0)
            return;
      labelEventString = msg;
      Print( " Upcoming: " + msg );
      if (!IsTesting() || IsVisualMode()) {
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
   }

};

//+------------------------------------------------------------------+
//| Метод Run класса TradePanel                                      |
//+------------------------------------------------------------------+
void TradePanel::Init()
{
   ObjectsDeleteAll(0,0,-1);
   // Comment("Программный код сгенерирован TradePanel ");
   //--- создаём главное окно и запускаем исполняемый модуль
   Property.H = 28;
   SetWin(5,25,1000,CORNER_LEFT_UPPER);

   str1EA.Property=Property;
   str2Spread.Property=Property;
   str3Trend.Property=Property;
   str4Senti.Property=Property;
   str5News.Property=Property;
      
   ArrayResize(strNews, 1);
   strNews[0].Property = Property;
   
   str6Orders.Property=Property;
   ArrayResize(strOrders, methods.MaxOpenedTrades);
         
   //UpdateShowGlobalSentiments();
   //UpdateShowMarketInfo();
   bForceRedraw = true;

   //Draw();
}

//+------------------------------------------------------------------+
//| Метод Draw                                            
//+------------------------------------------------------------------+
void TradePanel::Draw()
{
   if (!bForceRedraw)
   {
      if (!AllowRedrawByEvenMinutesTimer())
         return;
   }
   bForceRedraw = false;
      
   UpdateShowGlobalSentiments();
   UpdateShowMarketInfo();
   
   int X,Y,B;
   X=w_xpos;
   Y=w_ypos;
   B=w_bsize;
   
   str1EA.Draw("Expert", X, Y, B, 0, EAString);
   Y=Y+Property.H+DELTA;
   if (bHideAll == false)
   {
      str2Spread.Draw("MarketInfo0", X, Y, B, 150, "Market Info", MarketInfoString);
      Y=Y+Property.H+DELTA;
      str3Trend.Draw("Trend0", X, Y, B, 100, "Trend", TrendString);
      Y=Y+Property.H+DELTA;
      str4Senti.Draw("Sentiments0", X, Y, B, 150, "Sentiments", SentiString);
      Y=Y+Property.H+DELTA;
      str5News.Draw("NewsStat0", X, Y, B, 0, NewsStatString);
      if (bHideNews == false)
      {
         string newsName = "News";
         for (int i=0; i < ArraySize(strNews);i++) 
         {
             newsName = StringFormat("News%d", i);
             Y=Y+Property.H+DELTA;
             strNews[i].Draw(newsName, X, Y, B, 0, "", NewsString);
         }
      }
      
      Y=Y+Property.H+DELTA;
      str6Orders.Draw("Orders0", X, Y, B, 0, OrdersString);
      if (bHideOrders == false)
      {
         OrderSelection* orders = methods.GetOpenOrders();
         
         for (int i = 0; i < ArraySize(strOrders);i++) 
         {
            strOrders[i].Delete();
         }

         string ordersName = "";
         int i = 0;
         FOREACH_ORDER(orders)
         {
            strOrders[i].Property = Property;
            ordersName = StringFormat("Order%d", order.ticket);
            Y=Y+Property.H+DELTA;
            strOrders[i].Draw(ordersName, X, Y, B, 0, "", order.ToString());
            i++;
         }
      }
   }
   
   ChartRedraw();
   on_event=true;   // разрешаем обработку событий
}
//+------------------------------------------------------------------+
void TradePanel::SetWin(int m_xdelta,
                  int m_ydelta,
                  int m_bsize,
                  int m_corner)
{
//---
   if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_UPPER) w_corner=m_corner;
   else
      if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_UPPER) w_corner=m_corner;
   else
      if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_LOWER) w_corner=CORNER_LEFT_UPPER;
   else
      if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_LOWER) w_corner=CORNER_RIGHT_UPPER;
   else
     {
      Print("Error setting the anchor corner = ",m_corner);
      w_corner=CORNER_LEFT_UPPER;
     }
   if(m_xdelta>=0)w_xdelta=m_xdelta;
   else
     {
      Print("The offset error X = ",m_xdelta);
      w_xdelta=0;
     }
   if(m_ydelta>=0)w_ydelta=m_ydelta;
   else
     {
      Print("The offset error Y = ",m_ydelta);
      w_ydelta=0;
     }
   if(m_bsize>0)
     w_bsize=m_bsize;
   
   Property.Corner=(ENUM_BASE_CORNER)w_corner;
   SetXY(w_corner);
}

//+------------------------------------------------------------------+
void TradePanel::SetXY(int m_corner)
{
   if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_UPPER)
     {
      w_xpos=w_xdelta;
      w_ypos=w_ydelta;
      Property.Corn=1;
     }
   else
   if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_UPPER)
     {
      w_xpos=w_xdelta+w_bsize;
      w_ypos=w_ydelta;
      Property.Corn=-1;
     }
   else
   if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_LOWER)
     {
      w_xpos=w_xdelta;
      w_ypos=w_ydelta+w_hsize+Property.H;
      Property.Corn=1;
     }
   else
   if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_LOWER)
     {
      w_xpos=w_xdelta+w_bsize;
      w_ypos=w_ydelta+w_hsize+Property.H;
      Property.Corn=-1;
     }
   else
     {
      Print("Error setting the anchor corner = ",m_corner);
      w_corner=CORNER_LEFT_UPPER;
      w_xpos=0;
      w_ypos=0;
      Property.Corn=1;
     }
//---
   if((ENUM_BASE_CORNER)w_corner==CORNER_LEFT_UPPER) w_h_corner=CORNER_LEFT_LOWER;
   if((ENUM_BASE_CORNER)w_corner==CORNER_LEFT_LOWER) w_h_corner=CORNER_LEFT_LOWER;
   if((ENUM_BASE_CORNER)w_corner==CORNER_RIGHT_UPPER) w_h_corner=CORNER_RIGHT_LOWER;
   if((ENUM_BASE_CORNER)w_corner==CORNER_RIGHT_LOWER) w_h_corner=CORNER_RIGHT_LOWER;
//---
}
//+------------------------------------------------------------------+
//| Метод обработки события OnChartEvent класса TradePanel       |
//+------------------------------------------------------------------+
void TradePanel::OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam)
{
   if(on_event)
     {          
      //--- трансляция событий OnChartEvent
      str1EA.OnEvent(id,lparam,dparam,sparam);
      if (bHideAll == false)
      {
         str2Spread.OnEvent(id,lparam,dparam,sparam);
         str3Trend.OnEvent(id,lparam,dparam,sparam);
         str4Senti.OnEvent(id,lparam,dparam,sparam);
         str5News.OnEvent(id,lparam,dparam,sparam);
         if (bHideNews == false)
         {
            for (int i=0; i < ArraySize(strNews);i++) 
            {
               strNews[i].OnEvent(id,lparam,dparam,sparam);
            }
         }
         str6Orders.OnEvent(id,lparam,dparam,sparam);
         if ( bHideOrders == false)
         {
            for (int i = 0; i < ArraySize(strOrders); i++ ) 
            {
               strOrders[i].OnEvent(id,lparam,dparam,sparam);
            }
         }
      }
      
      //--- создание графического объекта
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CREATE)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW1] в редакторе Edit STR1
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_ENDEDIT
         && StringFind(sparam,".STR1",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW2] : кнопка Plus STR2
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR2",0)>0
         && StringFind(sparam,".Button3",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW2] : кнопка Minus STR2
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR2",0)>0
         && StringFind(sparam,".Button4",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Plus STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button3",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Minus STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button4",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Up STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button5",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Down STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button6",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [new4] STR4
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR4",0)>0
         && StringFind(sparam,".Button",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [NEW5] STR5
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR5",0)>0
         && StringFind(sparam,"(1)",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [new5] STR5
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR5",0)>0
         && StringFind(sparam,"(2)",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [] STR5
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR5",0)>0
         && StringFind(sparam,"(3)",0)>0)
        {
         //--- реакция на планируемое событие
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
           if (StringFind(sparam, str1EA.name) >= 0)
           {
              bHideAll = !bHideAll;
              if (bHideAll)
              {
                 str2Spread.Delete();
                 str3Trend.Delete();
                 str4Senti.Delete();
                 str5News.Delete();
                  for (int i=0; i < ArraySize(strNews);i++) 
                  {
                     strNews[i].Delete();
                  }
                  str6Orders.Delete();
                  for (int i=0; i < ArraySize(strOrders);i++) 
                  {
                     strOrders[i].Delete();
                  }
              }
           }
            
           if (StringFind(sparam, str5News.name)>=0)
           {
               bHideNews = !bHideNews;
               if (bHideNews)
               {
                  for (int i=0; i < ArraySize(strNews);i++) 
                  {
                     strNews[i].Delete();
                  }
               }
           }
               
           if (StringFind(sparam, str6Orders.name)>=0)
           {
               bHideOrders = !bHideOrders;
               if (bHideOrders)
               {
                  for (int i=0; i < ArraySize(strNews);i++) 
                  {
                     strOrders[i].Delete();
                  }
               }
           }
               
           Draw();
            //--- реакция на планируемое событие
        }
     }
          
}

