//+------------------------------------------------------------------+
//|  Expert Adviser Object                             Objective.mq4 |
//|                                 Copyright 2013, Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"

#include <XTrade\IUtils.mqh>
#include <XTrade\SmoothAlgorithms.mqh>
#include <XTrade\IndicatorsAlgorithms.mqh> 

//---- отрисовка индикатора в главном окне
#property indicator_chart_window 
//---- количество индикаторных буферов
#property indicator_buffers 3 
//---- использовано три графических построения
#property indicator_plots   3
//+-----------------------------------+
//|  Параметры отрисовки индикатора   |
//+-----------------------------------+
//---- отрисовка индикатора в виде линии
#property indicator_type1   DRAW_LINE
//---- в качестве цвета линии индикатора использован фиолетовый цвет
#property indicator_color1 clrSilver
//---- линия индикатора - непрерывная кривая
#property indicator_style1  STYLE_DASHDOTDOT
//---- толщина линии индикатора равна 1
#property indicator_width1  1
//---- отображение лэйбы индикатора
#property indicator_label1  "Upper Bollinger"

//---- отрисовка индикатора в виде линии
#property indicator_type2   DRAW_LINE
//---- в качестве цвета линии индикатора использован фиолетовый цвет
#property indicator_color2 clrSilver
//---- линия индикатора - непрерывная кривая
#property indicator_style2  STYLE_DASHDOTDOT
//---- толщина линии индикатора равна 1
#property indicator_width2  1
//---- отображение лэйбы индикатора
#property indicator_label2  "Middle Bollinger"

//---- отрисовка индикатора в виде линии
#property indicator_type3   DRAW_LINE
//---- в качестве цвета линии индикатора использован фиолетовый цвет
#property indicator_color3 clrSilver
//---- линия индикатора - непрерывная кривая
#property indicator_style3  STYLE_DASHDOTDOT
//---- толщина линии индикатора равна 1
#property indicator_width3  1
//---- отображение лэйбы индикатора
#property indicator_label3  "Lower Bollinger"
//+-----------------------------------+
//|  ВХОДНЫЕ ПАРАМЕТРЫ ИНДИКАТОРА     |
//+-----------------------------------+
/*
enum Applied_price_ //Тип константы
{
  PRICE_CLOSE_ = 1,     //PRICE_CLOSE
  PRICE_OPEN_,          //PRICE_OPEN
  PRICE_HIGH_,          //PRICE_HIGH
  PRICE_LOW_,           //PRICE_LOW
  PRICE_MEDIAN_,        //PRICE_MEDIAN
  PRICE_TYPICAL_,       //PRICE_TYPICAL
  PRICE_WEIGHTED_,      //PRICE_WEIGHTED
  PRICE_SIMPL_,         //PRICE_SIMPL_
  PRICE_QUARTER_,       //PRICE_QUARTER_
  PRICE_TRENDFOLLOW0_, //PRICE_TRENDFOLLOW0_
  PRICE_TRENDFOLLOW1_  //PRICE_TRENDFOLLOW1_
};

*/
input int BandsPeriod = 20; //Период усреднения
input double BandsDeviation = 2.0; //Девиация 
input ENUM_MA_METHOD MA_Method = MODE_LWMA; //метод усреднения
input Applied_price_ IPC = PRICE_CLOSE_;//ценовая константа
/* 
  , по которой производится расчёт индикатора ( 1-CLOSE, 2-OPEN, 3-HIGH, 4-LOW, 
  5-MEDIAN, 6-TYPICAL, 7-WEIGHTED, 8-SIMPL, 9-QUARTER, 10-TRENDFOLLOW, 11-0.5 * TRENDFOLLOW.) 
*/ 
int Shift = 0; // сдвиг индикатора по горизонтали в барах
//---+
//---- индикаторные буферы
double UpperBuffer[];
double MiddleBuffer[];
double LowerBuffer[];
//+X================================================================X+
// Описание классов усреднения и индикаторов                         |
//+X================================================================X+ 

int ThriftPORT = Constants::MQL_PORT;

//+X================================================================X+    
//| BBands indicator initialization function                         | 
//+X================================================================X+  
void OnInit()
{

   string name = StringFormat("BBands(BandsPeriod = %d, BandsDeviation = %g)", BandsPeriod, BandsDeviation);
   Utils = CreateUtils((short)ThriftPORT, name); 
   if (Utils == NULL)
      Print("Failed create Utils!!!");
      
   //Utils.SetIndiName(name);

//----+  
  //---- превращение динамического массива в индикаторный буфер
  SetIndexBuffer(0, UpperBuffer, INDICATOR_DATA);
  //---- осуществление сдвига индикатора 1 по горизонтали на AroonShift
  PlotIndexSetInteger(0, PLOT_SHIFT, Shift);
  //---- осуществление сдвига начала отсчёта отрисовки индикатора 1
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, BandsPeriod - 1);
  //--- создание метки для отображения в DataWindow
  PlotIndexSetString(0, PLOT_LABEL, "Upper Bollinger");
  //---- установка значений индикатора, которые не будут видимы на графике
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  
  //---- превращение динамического массива в индикаторный буфер
  SetIndexBuffer(1, MiddleBuffer, INDICATOR_DATA);
  //---- осуществление сдвига индикатора 2 по горизонтали
  PlotIndexSetInteger(1, PLOT_SHIFT, Shift);
  //---- осуществление сдвига начала отсчёта отрисовки индикатора 2
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, BandsPeriod - 1);
  //--- создание метки для отображения в DataWindow
  PlotIndexSetString(1, PLOT_LABEL, "Middle Bollinger");
  //---- установка значений индикатора, которые не будут видимы на графике
  PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  
  //---- превращение динамического массива в индикаторный буфер
  SetIndexBuffer(2, LowerBuffer, INDICATOR_DATA);
  //---- осуществление сдвига индикатора 3 по горизонтали
  PlotIndexSetInteger(2, PLOT_SHIFT, Shift);
  //---- осуществление сдвига начала отсчёта отрисовки индикатора 3
  PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, BandsPeriod - 1);
  //--- создание метки для отображения в DataWindow
  PlotIndexSetString(2, PLOT_LABEL, "Lower Bollinger");
  //---- установка значений индикатора, которые не будут видимы на графике
  PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  
  //---- инициализации переменной для короткого имени индикатора
  //string shortname;
  //StringConcatenate(shortname, "BBands( BandsPeriod = ", BandsPeriod,
  //                             ", BandsDeviation = ", BandsDeviation, ")");  
  //--- создание имени для отображения в отдельном подокне и во всплывающей подсказке
  //IndicatorSetString(INDICATOR_SHORTNAME, shortname);
  //--- определение точности отображения значений индикатора
  IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);
//----+ завершение инициализации
 }
 
void OnDeinit(const int reason) 
{
  DELETE_PTR(Utils)
}

//+X================================================================X+  
//| BBands iteration function                                        | 
//+X================================================================X+  
int OnCalculate(
                const int rates_total,    // количество истории в барах на текущем тике
                const int prev_calculated,// количество истории в барах на предыдущем тике
                const datetime& time[],
                const double& open[],    
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[]
               )
{
//----+   
   //---- проверка количества баров на достаточность для расчёта
   if (rates_total < BandsPeriod) return(0);
    
   //---- Объявление переменных с плавающей точкой  
   double price_;
   //----+ Объявление целых переменных и получение уже посчитанных баров
   int first, bar;
   
   //---- расчёт стартового номера first для цикла пересчёта баров
   if (prev_calculated == 0) // проверка на первый старт расчёта индикатора
        first = 0; // стартовый номер для расчёта всех баров
   else first = prev_calculated - 1; // стартовый номер для расчёта новых баров
   
   //---- объявление переменных классов Moving_Average и StdDeviation
   static CBBands BBands;
   
   //---- Основной цикл расчёта индикатора
   for(bar = first; bar < rates_total; bar++)
    {
     //----+ Обращение к функции PriceSeries для получения входной цены Series
     price_ = PriceSeries(IPC, bar, open, low, high, close);
     BBands.BBandsSeries(0, prev_calculated, rates_total,
                BandsPeriod, BandsDeviation, MA_Method, price_, bar, false,
                           LowerBuffer[bar], MiddleBuffer[bar], UpperBuffer[bar]);
    }
//----+     
   return(rates_total);
}
//+X----------------------+ <<< The End >>> +-----------------------X+
