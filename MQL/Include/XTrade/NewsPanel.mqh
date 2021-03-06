//+------------------------------------------------------------------+
//|                                                 NewsPanel.mqh    |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

//--- Подключаем файлы классов
#include <XTrade\PanelBase.mqh>
#include <XTrade\IUtils.mqh>
#include <XTrade\ClassRow.mqh>
#include <XTrade\ITradeService.mqh>

//+------------------------------------------------------------------+
//| класс NewsPanel (Главный модуль)                                 |
//+------------------------------------------------------------------+
class NewsPanel : public PanelBase
{
protected:
   ITradeService* thrift;
public:
   datetime          current_time;
   string            EAString;
   bool              bHideNews;
   string            NewsStatString;
   //---
   CRowType1         str5News;       // объявление строки класса
   CRowTypeLabel*    strNews[];
   SignalNews        news_arr[MAX_NEWS_PER_DAY];

   double SentiLongPos;
   double SentiShortPos;
   ENUM_TRADE_PANEL_SIZE panelSize;
   int MinImportance;
   ENUM_TIMEFRAMES CurrTF;
  
   NewsPanel(ENUM_TRADE_PANEL_SIZE ps, int MI, int SubW, ENUM_TIMEFRAMES tf) 
     :PanelBase(ChartID(), SubW), str5News(GetPointer(this))
   {
      CurrTF = tf;
      //thrift = th;
      panelSize = ps;
      MinImportance = MI;
      //EAFileName = eaname + ".exp";
      thrift = Utils.Service();
      EAString = StringFormat("%s %d", thrift.Name(), thrift.MagicNumber());
      bHideNews = false;
      
      SentiLongPos = -1;
      SentiShortPos = -1;
      current_time = 0;
      
   }   
   
   void ~NewsPanel() 
   {
      str5News.Delete();
      for (int i = 0; i < ArraySize(strNews);i++) 
      {
         strNews[i].Delete();
         DELETE_PTR(strNews[i]);
      }      
   }
   void              CreateGlobalSignal(SignalNews& news0);
   void              Init(int Magic, int ThriftPort, int NewsImportance);
   void              ObtainNews(datetime curtime);

   //void              Hide();          // метод: свернуть окно
   virtual void      OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam);
   virtual void              Draw();
   void              Resize();
   

};

//+------------------------------------------------------------------+
//| Метод Run класса TradePanel                                      |
//+------------------------------------------------------------------+
void NewsPanel::Init(int Ma, int ThPort, int NewsImp)
{
   ObjectsDeleteAll(chartID,subWin,-1);
   Resize();   
   ArrayResize(strNews, MAX_NEWS_PER_DAY);   
   for (int i = 0; i < ArraySize(strNews);i++) 
   {
      strNews[i] = new CRowTypeLabel(GetPointer(this));
   }      

   bForceRedraw = true;
}

void NewsPanel::Resize()
{
   int height = (int)ChartGetInteger(chartID,CHART_HEIGHT_IN_PIXELS,subWin); 
   if (panelSize == PanelNormal)
   {
      Property.H = 28; // height of fonts
      height = (height == 0)?20:(height-20);
      SetWin(5,height,1000,CORNER_LEFT_LOWER);
   } else if (panelSize == PanelSmall)
            {
               Property.H = 25; // height of fonts
               height = (height == 0)?10:(height-10);
               SetWin(5,height - 10,700,CORNER_LEFT_LOWER);
            }
   str5News.Property=Property;
            
}

void NewsPanel::ObtainNews(datetime curtime)
{
   current_time = curtime;
   if (thrift.GetTodayNews((ushort)MinImportance, news_arr, curtime) > 0)
   {
   
   }
}

//+------------------------------------------------------------------+
//| Метод Draw                                            
//+------------------------------------------------------------------+
void NewsPanel::Draw()
{
   if (panelSize == PanelNone)
      return;
   if (!bForceRedraw)
   {
      if (!AllowRedrawByEvenMinutesTimer(Symbol(), CurrTF))
         return;
   }
   bForceRedraw = false;      
   
   int X,Y,B;
   X=w_xpos;
   Y=w_ypos;
   B=w_bsize;
   
   Y=Y-Property.H+DELTA;
   str5News.Draw("NewsStat0", X, Y, B, 0, NewsStatString);
   if (bHideNews == false)
   {
      string newsName = "News";
      string newst = "";
      for (int i = 0; i < MAX_NEWS_PER_DAY;i++ ) 
      {
         strNews[i].Property = Property;
         newsName = StringFormat("News%d", i);
         Y=Y-Property.H-DELTA;
         newst = news_arr[i].ToString();
         if (StringLen(newst) > 0)
         {
            strNews[i].Text.SetText(newst);
            strNews[i].Draw(newsName, X, Y, B);
         }
      }
  

   }
   
   ChartRedraw(chartID);
   on_event=true;   // разрешаем обработку событий
}


//+------------------------------------------------------------------+
//| Метод обработки события OnChartEvent класса TradePanel       |
//+------------------------------------------------------------------+
void NewsPanel::OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam)
{
   if(on_event)
     {         
      
      if(id==CHARTEVENT_CHART_CHANGE)
      {
         Resize();
         SetForceRedraw();
         ObtainNews(current_time);
         Draw();           
      }
      //--- трансляция событий OnChartEvent
      str5News.OnEvent(id,lparam,dparam,sparam);
      if (bHideNews == false)
      {
         for (int i=0; i < ArraySize(strNews);i++) 
         {
            strNews[i].OnEvent(id,lparam,dparam,sparam);
         }
      }

               
      //--- нажатие кнопки Close в главном окне
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".Button1",0)>0)
      {
         //--- реакция на планируемое событие
         //ExpertRemove();
         string name = thrift.Name();
         ChartIndicatorDelete(chartID, subWin, name);
      }
      //--- нажатие кнопки Hide в главном окне
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".Button0",0)>0)
        {
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
           SetForceRedraw();    
           ObtainNews(current_time);
           Draw();           
           return;
            //--- реакция на планируемое событие
        }
     }
          
}

