//MQL5 Version  June 21, 2010 Final
//+X================================================================X+
//|                                         IndicatorsAlgorithms.mqh |
//|                               Copyright © 2010, Nikolay Kositsin |
//|                              Khabarovsk,   farria@mail.redcom.ru | 
//+X================================================================X+
#property copyright "2010,   Nikolay Kositsin"
#property link      "farria@mail.redcom.ru"
#property version   "1.00"

//+X----------------------------------------------------------------X+
// Описание классов усреднения                                       | 
//+X----------------------------------------------------------------X+ 
#include <XTrade/SmoothAlgorithms.mqh> 
//+X================================================================X+
//|  Линейно-регрессионное усреднение произвольных ценовых рядов     |
//+X================================================================X+
class CLRMA  
 {
public:   
  double LRMASeries(uint begin,// номер начала достоверного отсчёта баров
                     uint prev_calculated,// Количество истории в барах на предыдущем тике
                     uint rates_total,// Количество истории в барах на текущем тике
                     int Length,// Период усреднения
                     double series,// Значение ценового ряда, расчитанное для бара с номером bar
                     uint bar,// Номер бара
                     bool set // Направление индексирования массивов.
                     )
  {
//----+
   //---- Объявление локальных переменных
   double sma, lwma, lrma;  
  
   //---- объявление переменных класса Moving_Average из файла MASeries_Cls.mqh
  // CMoving_Average SMA, LWMA;
  
   //---- Получение значений мувингов  
   sma = m_SMA.SMASeries(begin, prev_calculated, rates_total, Length, series, bar, set);
   lwma = m_LWMA.LWMASeries(begin, prev_calculated, rates_total, Length, series, bar, set);
 
   //---- Вычисление LRMA
   lrma = 3.0 * lwma - 2.0 * sma;
//----+
   return(lrma); 
  };

protected:
 //---- объявление переменных класса СMoving_Average
 CMoving_Average m_SMA, m_LWMA;  
 };
//+X================================================================X+
//|  Алгоритм получения канала Боллинджера от мувинга VIDYA          |
//+X================================================================X+
class CVidyaBands
 {
public:
  double VidyaBandsSeries(uint begin, // номер начала достоверного отсчёта баров
                           uint prev_calculated, // Количество истории в барах на предыдущем тике
                           uint rates_total, // Количество истории в барах на текущем тике
                           int CMO_period, // Период усреднения осциллятора CMO
                           double EMA_period, // EMA период усреднения
                           int BBLength, // Период усреднения канала Боллинджера
                           double deviation, // Девиация
                           double series,  // Значение ценового ряда, расчитанное для бара с номером bar
                           uint bar,  // Номер бара
                           bool set, // Направление индексирования массивов
                           double& DnMovSeries, // Значение нижней границы канала для текущего бара 
                           double& MovSeries,  // Значение средней линии канала для текущего бара 
                           double& UpMovSeries  // Значение верхней границы канала для текущего бара 
                          ) 
   {
//----+
    //----+ Вычисление средней линии    
    MovSeries = m_VIDYA.VIDYASeries(begin, prev_calculated, rates_total, CMO_period, EMA_period, series, bar, set);
  
    //----+ Вычисление канала Боллинджера
    double StdDev = m_STD.StdDevSeries(begin+CMO_period+1, prev_calculated, rates_total, BBLength, deviation, series, MovSeries, bar, set);
    DnMovSeries = MovSeries - StdDev;
    UpMovSeries = MovSeries + StdDev;
//----+
    return(StdDev); 
   }
 
  protected:
    //---- объявление переменных классов CCMO и CStdDeviation
    CCMO           m_VIDYA;
    CStdDeviation  m_STD;
 };
//+X================================================================X+
//|  Алгоритм получения канала Боллинджера                           |
//+X================================================================X+
class CBBands
 {
public:
  double BBandsSeries(uint begin, // номер начала достоверного отсчёта баров
                       uint prev_calculated, // Количество истории в барах на предыдущем тике
                       uint rates_total, // Количество истории в барах на текущем тике
                       int Length, // Период усреднения
                       double deviation, // Девиация
                       ENUM_MA_METHOD MA_Method, // Метод усреднения
                       double series,  // Значение ценового ряда, расчитанное для бара с номером bar
                       uint bar,  // Номер бара
                       bool set, // Направление индексирования массивов
                       double& DnMovSeries, // Значение нижней границы канала для текущего бара 
                       double& MovSeries,  // Значение средней линии канала для текущего бара 
                       double& UpMovSeries  // Значение верхней границы канала для текущего бара 
                       ); 
                       
  double BBandsSeries_(uint begin, // номер начала достоверного отсчёта баров
                        uint prev_calculated, // Количество истории в барах на предыдущем тике
                        uint rates_total, // Количество истории в барах на текущем тике
                        int MALength, // Период усреднения мувинга
                        ENUM_MA_METHOD MA_Method, // Метод усреднения
                        int BBLength, // Период усреднения канала Боллинджера
                        double deviation, // Девиация
                        double series,  // Значение ценового ряда, расчитанное для бара с номером bar
                        uint bar,  // Номер бара
                        bool set, // Направление индексирования массивов
                        double& DnMovSeries, // Значение нижней границы канала для текущего бара 
                        double& MovSeries,  // Значение средней линии канала для текущего бара 
                        double& UpMovSeries  // Значение верхней границы канала для текущего бара 
                        ); 
  protected:
    //---- объявление переменных классов СMoving_Average и CStdDeviation
    CStdDeviation     m_STD;
    CMoving_Average   m_MA;
 };
//+X================================================================X+
//|  Вычисление канала Боллинджера                                   |
//+X================================================================X+    
double CBBands::BBandsSeries
 (
  uint begin, // номер начала достоверного отсчёта баров
  uint prev_calculated, // Количество истории в барах на предыдущем тике
  uint rates_total, // Количество истории в барах на текущем тике
  int Length, // Период усреднения
  double deviation, // Девиация
  ENUM_MA_METHOD MA_Method, //метод усреднения
  double series,  // Значение ценового ряда, расчитанное для бара с номером bar
  uint bar,  // Номер бара
  bool set, // Направление индексирования массивов
  double& DnMovSeries, // Значение нижней границы канала для текущего бара 
  double& MovSeries, // Значение средней линии канала для текущего бара
  double& UpMovSeries // Значение верхней границы канала для текущего бара
 )
// BBandsMASeries(begin, prev_calculated, rates_total, period, deviation,
          // MA_Method, Series, bar, set, DnMovSeries, MovSeries, UpMovSeries) 
//+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+
 {
//----+
  //----+ Вычисление средней линии
  MovSeries = m_MA.MASeries(begin, prev_calculated, rates_total, Length, MA_Method, series, bar, set);
  
  //----+ Вычисление канала Боллинджера
  double StdDev = m_STD.StdDevSeries(begin, prev_calculated, rates_total, Length, deviation, series, MovSeries, bar, set);
  DnMovSeries = MovSeries - StdDev;
  UpMovSeries = MovSeries + StdDev;
//----+
  return(StdDev); 
 }
//+X================================================================X+
//|  Вычисление канала Боллинджера                                   |
//+X================================================================X+    
double CBBands::BBandsSeries_
 (
  uint begin, // номер начала достоверного отсчёта баров
  uint prev_calculated, // Количество истории в барах на предыдущем тике
  uint rates_total, // Количество истории в барах на текущем тике
  int MALength, // Период усреднения мувинга
  ENUM_MA_METHOD MA_Method, //метод усреднения
  int BBLength, // Период усреднения канала Боллинджера
  double deviation, // Девиация
  double series,  // Значение ценового ряда, расчитанное для бара с номером bar
  uint bar,  // Номер бара
  bool set, // Направление индексирования массивов
  double& DnMovSeries, // Значение нижней границы канала для текущего бара 
  double& MovSeries, // Значение средней линии канала для текущего бара
  double& UpMovSeries // Значение верхней границы канала для текущего бара
 )
// BBandsMASeries_(begin, prev_calculated, rates_total, MALength, MA_Method,
      // deviation, BBLength, Series, bar, set, DnMovSeries, MovSeries, UpMovSeries) 
//+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+
 {
//----+
  //----+ Вычисление средней линии
  MovSeries = m_MA.MASeries(begin, prev_calculated, rates_total, MALength, MA_Method, series, bar, set);
  
  //----+ Вычисление канала Боллинджера
  double StdDev = m_STD.StdDevSeries(begin+MALength+1, prev_calculated, rates_total, BBLength, deviation, series, MovSeries, bar, set);
  DnMovSeries = MovSeries - StdDev;
  UpMovSeries = MovSeries + StdDev;
//----+
  return(StdDev); 
 }
//+X----------------------+ <<< The End >>> +-----------------------X+