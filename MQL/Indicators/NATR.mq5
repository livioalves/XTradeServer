//+------------------------------------------------------------------+
//|                                                          ATR.mq5 |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2009-2017, MetaQuotes Software Corp."
#property link        "http://www.mql5.com"
#property description "Average True Range"
#include <XTrade\IUtils.mqh>
#property  strict

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  DodgerBlue
#property indicator_label1  "NATR"


//--- input parameters
input int InpAtrPeriod=14;  // ATR period
input int InpAtrPercent=20;
input bool PercentileATR = false;

//--- indicator buffers
double    ExtATRBuffer[];
double    ExtTRBuffer[];
//--- global variable
int       ExtPeriodATR;

int ThriftPORT = Constants::MQL_PORT;
bool setAsSeries = true;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
//--- check for input value
   if(InpAtrPeriod<=0)
   {
      ExtPeriodATR=14;
      printf("Incorrect input parameter InpAtrPeriod = %d. Indicator will use value %d for calculations.",InpAtrPeriod,ExtPeriodATR);
   }
   else 
      ExtPeriodATR = InpAtrPeriod;

   setAsSeries = PercentileATR;
      
#ifdef __MQL4__
   IndicatorBuffers(2);
   SetIndexStyle(0, DRAW_LINE);
   SetIndexLabel(0, name);
   SetIndexDrawBegin(0, InpAtrPeriod);   
   PercentileATR = true;
#endif    

   string name = StringFormat("NATR(%s, %d, %d, %d, AsSeries=%d)", EnumToString((ENUM_TIMEFRAMES)Period()), ExtPeriodATR, InpAtrPercent, PercentileATR, 
   ArrayGetAsSeries(ExtATRBuffer));
   Utils = CreateUtils((short)ThriftPORT, name); 
   if (Utils == NULL)
      Print("Failed create Utils!!!");      


   Utils.SetIndiName(name);
      
   Utils.AddBuffer(0, ExtATRBuffer, setAsSeries, "NATR", InpAtrPeriod, INDICATOR_DATA, 0);
   Utils.AddBuffer(1, ExtTRBuffer, setAsSeries, "NATRC", InpAtrPeriod, INDICATOR_CALCULATIONS, 0);

   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpAtrPeriod);
//--- name for DataWindow and indicator subwindow label   
   //setAsSeries = ArrayGetAsSeries(ExtATRBuffer);      
   PlotIndexSetString(0,PLOT_LABEL,name);
   Utils.Info(StringFormat("Init %s", name));
}
  
void OnDeinit(const int reason) 
{
  DELETE_PTR(Utils)
}

//+------------------------------------------------------------------+
//| Average True Range                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
//#ifdef __MQL5__     
   //ArraySetAsSeries(ExtATRBuffer, setAsSeries);
   //ArraySetAsSeries(ExtTRBuffer, setAsSeries);
   //ArraySetAsSeries(time, setAsSeries);
   ArraySetAsSeries(open, setAsSeries);
   ArraySetAsSeries(close, setAsSeries);
   ArraySetAsSeries(high, setAsSeries);
   ArraySetAsSeries(low, setAsSeries);

//#endif

   int i,limit = 0;
//--- check for bars count
   if(rates_total<=ExtPeriodATR)
      return(0); // not enough bars for calculation
      
   int cut_num = 0;
   if ( PercentileATR )  //Общее количество элементов для обрезания с каждой стороны
      cut_num = (int)MathCeil((ExtPeriodATR*InpAtrPercent)*0.01/2);

   if ( !PercentileATR )
   {
   
      if(prev_calculated==0)
      {
         ExtTRBuffer[0]=0.0;
         ExtATRBuffer[0]=0.0;
         //--- filling out the array of True Range values for each period
         for(i=1;i<rates_total ;i++) //&& !IsStopped()
            ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
         //--- first AtrPeriod values of the indicator are not calculated
         double firstValue=0.0;
         for(i=1;i<=ExtPeriodATR;i++)
           {
            ExtATRBuffer[i]=0.0;
            firstValue+=ExtTRBuffer[i];
           }
         //--- calculating the first value of the indicator
         firstValue/=ExtPeriodATR;
         //if (PercentileATR)
         //    ExtATRBuffer[ExtPeriodATR] = CalcPercentileATR(ExtPeriodATR, cut_num, low, high, close);
         //else 
             ExtATRBuffer[ExtPeriodATR]=firstValue;
         limit = ExtPeriodATR+1;
      }
      else
       limit = prev_calculated-1;
       
   //--- the main loop of calculations
      for(i=limit;i<rates_total ;i++) //&& !IsStopped()
      {
         ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
         //if (PercentileATR)
         //   ExtATRBuffer[i] = CalcPercentileATR(i-ExtPeriodATR, cut_num, low, high, close);
         //else 
            ExtATRBuffer[i]=ExtATRBuffer[i-1]+(ExtTRBuffer[i]-ExtTRBuffer[i-ExtPeriodATR])/ExtPeriodATR;
      }
         return rates_total;

   } else {   
      int counted_bars = prev_calculated;// IndicatorCounted();
      //Общее количество элементов для обрезания с каждой стороны
      i=Utils.Bars()-ExtPeriodATR-1;// Индекс первого непосчитанного
      if(counted_bars >= ExtPeriodATR) 
          i = Utils.Bars() - counted_bars - 1;
      limit = i;    
      while(i>=0)
      {
         ExtATRBuffer[i] = CalcPercentileATR(i, cut_num, low, high, close);      
         i--;
      }
   }

   return(limit);
}
  
//+------------------------------------------------------------------+


double CalcPercentileATR(int i, int cut_num, const double &low[], const double &high[], const double &close[])
{
   int cnt = 0;
   // Percentile ATR calculations
   //Переменная результата
   double rez=0;
   //Переменная для формирования истинного диапазона
   double tr=0;
   //Переменная для расчета среднего
   double sred=0;
   double myarray[];
      ArrayResize(myarray, ExtPeriodATR);
      ArrayInitialize(myarray,0);
      ArraySetAsSeries(myarray, setAsSeries);
      //Заполняем значениями True Range
      for (cnt=1; cnt<=(ExtPeriodATR); cnt++)
      {
         //Сохраняем данные по размерам свечек в копилку
         //myarray[cnt-1]=Close[i+cnt-1];
         //Берем и сами создаем расчет Истинного диапазона
         tr=MathMax(MathAbs(high[i+cnt-1]-low[i+cnt-1]), MathAbs(high[i+cnt-1]-close[i+cnt-1+1]));
         tr=MathMax(tr, MathAbs(low[i+cnt-1]-close[i+cnt-1+1]));
         myarray[cnt-1]=tr;
      }
      //Сортируем матрицу в порядке возрастания
      ArraySort(myarray);
      //Вынимаем нужный элемент
      //rez=myarray[numer-1];
      //Считаем среднее из данных
      sred=0;
      for (cnt=cut_num; cnt<=(ExtPeriodATR-cut_num-1);cnt++)
      {
         //Суммируем
         sred=sred+myarray[cnt];
      }
      //Считаем результат для выдачи
      rez=sred/(ExtPeriodATR-cut_num*2);
  return rez;
}

