#property library
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <Arrays\List.mqh>
#include "ClassPriceHistogram.mqh"
#include "ClassProgressBar.mqh"

//+------------------------------------------------------------------+
//|   Класс CExpert                                                  |
//|   Описание класса                                                |
//+------------------------------------------------------------------+
class CExpert
  {
public:
   int               DaysForCalculation; // Дней для расчета(-1 вся) / Days for calculation(-1 all)
   int               DayTheHistogram;    // Дней с гистограммой / Days The Histogram
   int               RangePercent;       // Процент диапазона / Range%
   color             InnerRange;         // Цвет внутренний диапазон / Color internal range
   color             OuterRange;         // Цвет внешний диапазон / Color outer range
   color             ControlPoint;       // Цвет Контрольная точка(POC) / Color Point of Control
   bool              ShowValue;          // Показать значения / Show Value
   bool              ShowHistogram;
                                         // Приватные переменные класса / Private variables of a class
private:
   CList             list_object;        // Динамический список экземпляров класса CObject / The dynamic list of copies of class CObject 
   string            name_symbol;        // Имя символа / Symbol name
   int               count_bars;         // Количество дневных баров / Quantity of day bars
   bool              event_on;           // Флаг обработки событий / Flag of processing of events

public:
   
   // Конструктор класса / The designer of a class
                     CExpert();
   // Деструктор класса / Class destructor
                    ~CExpert(){Deinit(REASON_CHARTCLOSE);}
   // Метод инициализации / Initialization method
   bool              Init();
   // Метод деинициализации / Deinitialization method
   void              Deinit(const int reason);
   // Метод обработки OnTick / Method of processing OnTick
   void              OnTick();
   // Метод обработки события OnChartEvent() / Method of processing of event OnChartEvent ()
   void              OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   // Метод обработки события OnTimer() / Method of processing of event OnTimer ()
   void              OnTimer();
   void              ReloadExpert();

  };
//+------------------------------------------------------------------+
//|   Конструктор класса / The designer of a class                   |
//+------------------------------------------------------------------+
CExpert::CExpert()
  {
   name_symbol=NULL;
   count_bars=0;
   RangePercent=70;
   InnerRange=Indigo;
   OuterRange=Magenta;
   ControlPoint=Orange;
   ShowValue=true;
   DaysForCalculation=100;
   DayTheHistogram=10;
   event_on=false;
   ShowHistogram = true;
  }
//+------------------------------------------------------------------+
//|   Метод инициализации / Initialization method                    |
//+------------------------------------------------------------------+
bool CExpert::Init()
  {
   int   rates_total,count;
   datetime day_time_open[];

// Проверка изменения Символа / Check of change of the Symbol
   if(name_symbol==NULL || name_symbol!=Symbol())
     {
      list_object.Clear();
      event_on=false;   // Опускаем флаг обработки событий / We lower a flag of processing of events
      Sleep(100);
      name_symbol=Symbol();
      // Получение массива времени открытия дней / Reception of a file of time of opening of days
      int err=0;
      do
        {
         // Расчет количества дней исходя из доступной истории / Account of quantity of days proceeding from an accessible history
         count_bars=Bars(NULL,PERIOD_D1);
         if(DaysForCalculation+1<count_bars)
            count=DaysForCalculation+1;
         else
            count=count_bars;
         if(DaysForCalculation<=0) count=count_bars;
         rates_total=CopyTime(NULL,PERIOD_D1,0,count,day_time_open);
         Sleep(1);
         err++;
        }
      while(rates_total<=0 && err<AMOUNT_OF_ATTEMPTS);
      if(err>=AMOUNT_OF_ATTEMPTS)
        {
         Print("There is no accessible history PERIOD_D1");
         name_symbol=NULL;
         return(false);
        }

      // Проверяем является 0 день текущим или нет(для акций и пятницы)
      // We check 0 day is current or not (for shares and Friday)
//      if(day_time_open[rates_total-1]+PeriodSeconds(PERIOD_D1)>=TimeTradeServer())
//         rates_total--;

      // Создаем объект для вывода на график процесса загрузки
      // We create object for a conclusion to the schedule of process of loading
      CProgressBar   *progress=new CProgressBar;
      progress.Create(0,"Loading",0,150,20);
      progress.Text("Calculation:");
      progress.Maximum=rates_total;
      // В данном цикле происходит создание объекта CPriceHistogram его инициализация и внесение в список объектов
      // In the given cycle there is a creation of object CPriceHistogram its initialization and entering into the list of objects
      for(int i=0;i<rates_total;i++)
      {
         CPriceHistogram  *hist_obj=new CPriceHistogram();
         //         hist_obj.StepHistigram(step);
         // Устанавливаем флаг отображения текстовых меток / We establish a flag of display of text labels
         hist_obj.ShowLevel(ShowValue);
         // Устанавливаем цвет POCs / We establish colour POCs
         hist_obj.ColorPOCs(ControlPoint);
         // Устанавливаем цвет внутри диапазона / We establish colour in a range
         hist_obj.ColorInner(InnerRange);
         // Устанавливаем цвет за диапазоном / We establish colour behind a range
         hist_obj.ColorOuter(OuterRange);
         // Устанавливаем процент диапазона / We establish range percent
         hist_obj.RangePercent(RangePercent);
         //hist_obj.ShowHistogram(this.ShowHistogram);

         //         hist_obj.ShowSecondaryPOCs((i>=rates_total-DayTheHistogram),PeriodSeconds(PERIOD_D1));
         if(hist_obj.Init(day_time_open[i],day_time_open[i]+PeriodSeconds(PERIOD_D1),this.ShowHistogram)) //(i>=rates_total-DayTheHistogram)
            list_object.Add(hist_obj);
         else
            delete hist_obj; // Удаляем если возникла ошибка / We delete if there was an error
         progress.Value(i);
      }
      delete progress;
      ChartRedraw(0);
      event_on=true;    // Поднимаем флаг обработки событий / We hoist the colours processings of events
     }
   else
      OnTick();
//---
   return(true);
  }
//+------------------------------------------------------------------+
//|   Метод обработки OnTick / Method of processing OnTick           |
//+------------------------------------------------------------------+
void CExpert::OnTick(void)
  {
   int count;
// Проверяем наличие нового дня / We check presence of new day
   if(count_bars!=Bars(NULL,PERIOD_D1))
     {
      name_symbol=NULL;
      Init();
     }
   else
     {
      count=list_object.Total();
      for(int i=0;i<count;i++)
        {
         CPriceHistogram  *hist_obj=list_object.GetNodeAtIndex(i);
         if(hist_obj.VirginPOCs())
            hist_obj.RefreshPOCs();
        }
     }
   return;
  }
//+------------------------------------------------------------------+
//|   Метод деинициализации / Deinitialization method                |
//+------------------------------------------------------------------+
void CExpert::Deinit(const int reason)
  {
   switch(reason)
     {
      case REASON_PARAMETERS: //Входные параметры были изменены пользователем
         name_symbol=NULL;
         break;
      case REASON_ACCOUNT:    //Активирован другой счет
      case REASON_CHARTCLOSE: //График закрыт
      case REASON_INITFAILED: //Признак того, что обработчик OnInit() вернул ненулевое значение
      case REASON_RECOMPILE:  //Программа перекомпилирована
      case REASON_REMOVE:     //Программа удалена с графика
      case REASON_TEMPLATE:   //Применен другой шаблон графика
      case REASON_CHARTCHANGE://Символ или период графика был изменен
         break;
     }
   return;
  }
//+------------------------------------------------------------------------------------------+
//|   Метод обработки события OnChartEvent() / Method of processing of event OnChartEvent () |
//+------------------------------------------------------------------------------------------+
void CExpert::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if (lparam==82) // r key
   {
      ReloadExpert();
   }

   if(event_on)   // Если в данный момент не происходит инициализация класса
     {            // If at present there is no class initialization
      switch(id)
        {
         case CHARTEVENT_KEYDOWN:
            // Событие нажатия клавиатуры, когда окно графика находится в фокусе
            // Event of pressing of the keyboard when the schedule window is in focus
            break;
         case CHARTEVENT_OBJECT_CLICK:
            // Событие щелчка мыши на графическом объекте, принадлежащего графику
            // Event of click of the mouse on the graphic object, belonging to the schedule
            // Comment as show_second_poc = true by default in CPriceHistogram
            /*
              if(list_object.Total()!=0)
              {
               datetime serch=StringToTime(sparam);
               int count=list_object.Total();
               for(int i=0;i<count;i++)
                 {
                  CPriceHistogram  *hist_obj=list_object.GetNodeAtIndex(i);
                  if(hist_obj.GetStartDateTime()==serch)
                    {
                     hist_obj.ShowSecondaryPOCs(!hist_obj.ShowSecondaryPOCs());
                     color col=hist_obj.ColorInner();
                     hist_obj.ColorInner(hist_obj.ColorOuter());
                     hist_obj.ColorOuter(col);
                     ChartRedraw(0);
                     break;
                    }
                 }
              } */
            break;
         case CHARTEVENT_OBJECT_DRAG:
            // Событие перемещения графического объекта при помощи мыши
            // Event of moving of graphic object by means of the mouse
            break;
         case CHARTEVENT_OBJECT_ENDEDIT:
            // Событие окончания редактирования текста в поле ввода графического объекта LabelEdit
            // Event of the termination of editing of the text in the field of input of graphic object LabelEdit
            break;
         default:
            // Сюда попадем если появится что то новенькое :)
            // Here we will get if there will be that that brand new :)
            break;
        }
     }
}
  

//+---------------------------------------------------------------------------------+
//|   Метод обработки события OnTimer() / Method of processing of event OnTimer ()  |
//+---------------------------------------------------------------------------------+
void CExpert::OnTimer(void)
{
   if(event_on)
   {
      // Перед использованием необходимо в конструктор класса добавить строку:
      // EventSetTimer(время в секундах); , а в деструктор строку: EventKillTimer();
      // Before use it is necessary to add in the designer of a class a line:
      // EventSetTimer(time in seconds); and in a destructor a line: EventKillTimer();
   }
}
//+------------------------------------------------------------------+
