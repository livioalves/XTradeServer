//+------------------------------------------------------------------+
//|                                                   SingularMA.mq5 |
//|                               Copyright 2016, Roman Korotchenko  |
//|                         https://login.mql5.comru/users/Solitonic |
//|                                             Revision 26 Jun 2016 |
//+------------------------------------------------------------------+


#property copyright   "Copyright 2016, Roman Korotchenko"
#property link        "https://login.mql5.com/ru/users/Solitonic"

#property version   "1.00"
#property indicator_chart_window //---- ��������� ���������� � �������� ����
#property indicator_buffers 1    //---- ��� ������� � ��������� ���������� 
#property indicator_plots   1    //---- ������������ ����� ���� ����������� ����������
//--- plot Trend
#property indicator_label1  "Trend SSA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3  //---- ������� ����� ���������� ����� 

#include <XTrade\CCaterpillar.mqh>

//--- input parameters
input ENUM_TIMEFRAMES period= PERIOD_CURRENT;               // Calculation period to build the chart
input ENUM_TIMEFRAMES period_to_redraw=PERIOD_M3;           // Refresh period chart



input int      SegmentLength=120;    // �������� �������
input int      SegmentLag=50;        // ���� (� �������� �� 1/4 �� 1/2 ����� ��������)


input int      EigMax=10;            // ����� ��� (����������� ��������������� �������. "���" - ������)

input double   EigNoiseLevel=2.0;    // ����������� ������� ������ ���� � ��������� "������� ���������" ����
input int      EigNoiseFlag =0;      // ����� ����������� ����� ���
                                     // 0 - ������� ����������� ������������ ������� [EigMin,EigMax]. EigNoiseLevel ������������.
                                     // 1 - ����������� ������ �� �������� ������ EigNoiseLevel ��� ��������� �������  � ������� �������.
                                     // 2 - ����������� ������ �� �������� ������ EigNoiseLevel ��� ������ �������  � ������� �������.
                                     


//--- indicator buffers
double         TrendBuffer[];
double         ResultBuffer[];
//-- ����� ������� SSA - ������
CCaterpillar   Caterpillar;

//--- ��������������� ����������
int      EigMin=1;
double   wrkData[];
int      OldSegmentLength;
int      OldSegmentLag;
//
datetime start_data;           // Start time to build the chart
datetime stop_data;      // ������� �����

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,TrendBuffer,INDICATOR_DATA); 
   //ArraySetAsSeries(TrendBuffer,true);
   
   //--- ��������� ����� ��� ����������� ������ � �����, ��� �������
   // SetIndexBuffer(1,ResultBuffer,INDICATOR_CALCULATIONS);
  
  
  OldSegmentLength = 0;
  OldSegmentLag    = 0;
  
  ArrayResize(wrkData  ,SegmentLength, SERIA_DFLT_LENGTH);
  ArrayResize(ResultBuffer,SegmentLength, SERIA_DFLT_LENGTH);
   
//--- �������    
   string shortname;
   StringConcatenate(shortname, "SSA(", SegmentLength, ",", SegmentLag, ")", "C.�. 1-", EigMax);
   //--- �������� ����� ��� ����������� � DataWindow
   PlotIndexSetString(0, PLOT_LABEL, shortname);   
   
   
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
static int reCalcOn = 0, curCalcFinish = 1;
static int ReCalcLim = 7;
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
  int idx, nshift, ntime;
  
  int fEigMin = 1;      // ��� ������ ������ ���� = 1
  int fEigMax = EigMax; // ����������� ��������. ���������
  
  //--- ������� ���������� ��������� ����� ��� ������� ������� � ������� �� �������  
 // int nbars=Bars(Symbol(),0); 
   
  if( rates_total < SegmentLength ) {   
      PrintFormat("����� ������ ������ ����� ����������. ��� �������."); 
      return(0); 
  }

   
      reCalcOn++; 
   //if(reCalcOn != 1 )  curCalcFinish = 0; else  curCalcFinish = 1;
   curCalcFinish = (reCalcOn != 1 )? 0:1; // ����� ������� ����� �� ������ ������ ������, � � �������� 
       reCalcOn  = MathMod(reCalcOn, ReCalcLim);  // ������ 7 ����� ��������
    
         
   if (!curCalcFinish) // ���������� ������ �� ��������
   {
     if(prev_calculated != 0) { 
         ArrayCopy(TrendBuffer,ResultBuffer,rates_total-SegmentLength,0,SegmentLength);
     }
     else { // ������������ ������ ���� ��������
         ArrayFill (TrendBuffer,0, rates_total, EMPTY_VALUE); // ��������
     }     
    return(rates_total);  // ����� ������ ��������� ������� �������   
   }
   //---------------------------------------------------------------------------        
         
   //---- ���������� ����� ������
   if(ArraySize(wrkData)< SegmentLength) 
   {   
     ArrayResize(wrkData  ,SegmentLength, SERIA_DFLT_LENGTH);            
     reCalcOn = 1;   
   }
   
   if(OldSegmentLength != SegmentLength ||   OldSegmentLag != SegmentLag)
   {
      Caterpillar.TrendSize(SegmentLength, SegmentLag);
      OldSegmentLength = SegmentLength;
      OldSegmentLag    = SegmentLag;                         
      reCalcOn = 1;
      
     if(ArraySize(ResultBuffer)< SegmentLength) {
       ArrayResize(ResultBuffer,2*SegmentLength, SERIA_DFLT_LENGTH);  
     }
     
     ArrayFill(ResultBuffer,0, SegmentLength, EMPTY_VALUE); // ��������
     ArrayFill(TrendBuffer, 0, rates_total, EMPTY_VALUE);   // ��������
   }             
   
 
   
   curCalcFinish = 0; // ��������� ������ ������ ������, ���� �� �������� �������
   
   ntime  = ArraySize(time);       // ������������ rates_total
   nshift = ntime - SegmentLength; // ��������� ������ ��� ��������� ������� ������ 
 
   for( int i=0; i<SegmentLength; i++) 
   {
     idx = i+nshift;
     wrkData[i] = (high[idx] + low[idx] + close[idx])/3;     
   }

 // EigNoiseFlag: 0 (������� ����������� ������������ �������) ��� 1,2 (����������� ������ �� ������������ ���� EigNoiseLevel)
 // ���� EigNoiseFlag = 1,2 EigNoiseLevel ������ ���� � ���������! ����� ���� ���������� ��������������.
   Caterpillar.SetNoiseRegime(EigNoiseFlag, EigNoiseLevel);  
      
 // ���������� � �������������� � ����������� ���������������   
   Caterpillar.DoAnalyse(wrkData, SegmentLength, SegmentLag, fEigMin, fEigMax);     
          
       start_data  = time[nshift];   
       stop_data   = time[nshift+SegmentLength-1];
       
   ArrayFill(ResultBuffer,0, SegmentLength, EMPTY_VALUE);            
   
   for( int i= 0; i<SegmentLength; i++) 
   {      
      ResultBuffer[i] =  Caterpillar.Trend[i];//(high[i] + close[i])/2;//
   }                
   
   ArrayCopy(TrendBuffer,ResultBuffer,rates_total-SegmentLength,0,SegmentLength);
   
   ChartRedraw(0);    //--- ����������� �������
   curCalcFinish = 1; // �������� ����� ������
   return(rates_total);
 }
//+------------------------------------------------------------------+


