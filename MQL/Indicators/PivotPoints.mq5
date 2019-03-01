//+------------------------------------------------------------------+
//|  Expert Adviser Object                           PivotPoints.mq5 |
//|                                 Copyright 2013, Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"

#include <XTrade\IUtils.mqh>

#property indicator_chart_window
#property indicator_plots   4
#property indicator_buffers 4
#property indicator_color1 Red

#property indicator_type1 DRAW_LINE
#property indicator_color2 Red
#property indicator_type2 DRAW_LINE
#property indicator_color3 DeepSkyBlue
#property indicator_type3 DRAW_LINE
#property indicator_color4 DeepSkyBlue
#property indicator_type4 DRAW_LINE

#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 1
#property indicator_width4 1

#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_DASH
#property indicator_style3 STYLE_SOLID
#property indicator_style4 STYLE_DASH

#property indicator_label1  "R1"
#property indicator_label2  "R2"

#property indicator_label3  "S1"
#property indicator_label4  "S2"

//---- constants 
//#define  ShortName         "PZ Pivot Points"
#define  OLabel            "PZPVLabel"
#define  Shift             1

//-- Buffers
double FextMapBuffer1[];
double FextMapBuffer2[];
double FextMapBuffer4[];
double FextMapBuffer5[];

//-- Parameters
input ENUM_TIMEFRAMES    FTimeFrame  = PERIOD_D1;

color  ResistanceLabel = Red;
color  SupportLabel    = DodgerBlue;
int    LabelFontSize   = 10;

bool DisplayLabels = false;

//---- Internal
int    ThriftPORT = Constants::MQL_PORT;
bool setAsSeries = true;
int chartId = 0;
int SubWin = 0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//|------------------------------------------------------------------|
int OnInit()
{   
   chartId = (int)ChartID();
   string name = StringFormat("PivotPoints (%s)", EnumToString(FTimeFrame));
   Utils = CreateUtils((short)ThriftPORT, name); 
   if (Utils == NULL)
      Print("Failed create Utils!!!");
      
   Utils.SetIndiName(name);

   Utils.AddBuffer(0, FextMapBuffer1, setAsSeries, "R1",  0, 0, 0);
   Utils.AddBuffer(1, FextMapBuffer2, setAsSeries, "R2", 0, 0, 0);
   Utils.AddBuffer(2, FextMapBuffer4, setAsSeries, "S1", 0, 0, 0);
   Utils.AddBuffer(3, FextMapBuffer5, setAsSeries, "S2", 0, 0, 0);
  
   // Delete objects 
   //DeleteObjects();
   
   Utils.Info(StringFormat("Init %s", name));
   return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int DeleteObjects()
{
   int obj_total=ObjectsTotal(chartId);
   for(int i = obj_total - 1; i >= 0; i--)
   {
       string label = ObjectName(chartId, i);
       if(StringFind(label, OLabel) == -1) continue;
       ObjectDelete(chartId, label); 
   }     
   return(0);
}
 

void OnDeinit(const int reason) 
{
  DeleteObjects();
  DELETE_PTR(Utils)
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
#ifdef __MQL5__     
   ArraySetAsSeries(time, setAsSeries);
   ArraySetAsSeries(open, setAsSeries);
   ArraySetAsSeries(close, setAsSeries);
   ArraySetAsSeries(high, setAsSeries);
   ArraySetAsSeries(low, setAsSeries);
#endif

   // Start, limit, etc..
   int start = 1;
   int limit;
   int counted_bars = prev_calculated;//IndicatorCounted();
   
   // nothing else to do?
   if(counted_bars < 0) 
       return(-1);

   // do not check repeated bars
   limit = Utils.Bars() - 1;// - counted_bars;
   
   // Only for inferior timeframes!
   //if(Period() >= FTimeFrame) 
  //    return(0);
   
   // Iteration
   for(int pos = limit; pos >= start; pos--)
   {
      // Daily shift to use
      int dshift = iBarShift(Symbol(), FTimeFrame, time[pos], false);
      
      // High, low, close and open 
      double HIGH    = iHigh(Symbol(), FTimeFrame, dshift+1);
      double LOW     = iLow(Symbol(), FTimeFrame, dshift+1);
      double CLOSE   = iClose(Symbol(), FTimeFrame, dshift+1);
      double OPEN    = iOpen(Symbol(), FTimeFrame, dshift+1);
      
      // Pivot Point
      double pv = (HIGH + LOW + CLOSE) / 3;
      
      // Calcuations 
      FextMapBuffer1[pos] = (2 * pv) - LOW;                                   // R1
      FextMapBuffer4[pos] = (2 * pv) - HIGH;                                  // S1 
      FextMapBuffer2[pos] = (pv - FextMapBuffer4[pos]) + FextMapBuffer1[pos]; // R2
      FextMapBuffer5[pos] = pv - (FextMapBuffer1[pos] - FextMapBuffer4[pos]); // S2 
      //FextMapBuffer3[pos] = (pv - FextMapBuffer5[pos]) + FextMapBuffer2[pos]; // R3
      //FextMapBuffer6[pos] = pv - (FextMapBuffer2[pos] - FextMapBuffer5[pos]); // S3
   }

   // Draw labels
   DrawLabel("R1", Shift, FextMapBuffer1[Shift], ResistanceLabel, 0, time);
   DrawLabel("R2", Shift, FextMapBuffer2[Shift], ResistanceLabel, 0, time);
   //DrawLabel("R3", Shift, FextMapBuffer3[Shift], ResistanceLabel, 0);
   DrawLabel("S1", Shift, FextMapBuffer4[Shift], SupportLabel, 0, time);
   DrawLabel("S2", Shift, FextMapBuffer5[Shift], SupportLabel, 0, time);
   //DrawLabel("S3", Shift, FextMapBuffer6[Shift], SupportLabel, 0);
   
   // Bye
   return( rates_total);
}

void DrawLabel(string text, int shift, double vPrice, color vcolor, int voffset, const datetime& time[])
{
   // Time
   datetime x1 = time[shift];
   
   // Bye if I don't need you
   if(!DisplayLabels) 
      return;
   
   // Label
   string label = OLabel + text;
   
   // If object exists, detroy it -we might be repainting-
   if(ObjectFind(chartId, label) != -1) 
       ObjectDelete(chartId, label);
   
   ObjectCreate(chartId, label, OBJ_TEXT, 0, x1, vPrice);
   ObjectSetString(chartId, label, OBJPROP_TEXT, text);
   ObjectSetInteger(chartId,label,OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetString(chartId, label, OBJPROP_FONT, "Arial"); 
   ObjectSetInteger(chartId, label, OBJPROP_FONTSIZE, LabelFontSize); 
   ObjectSetInteger(chartId, label, OBJPROP_COLOR, vcolor); 
   ObjectSetInteger(chartId, label, OBJPROP_BACK, true);
}