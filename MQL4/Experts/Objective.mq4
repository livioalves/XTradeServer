//+------------------------------------------------------------------+
//|  Expert Adviser Object                             Objective.mq4 |
//|                                 Copyright 2013, Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"

#property strict

#ifdef __MQL4__
#include <stdlib.mqh>
#include <FXMind\MT4Utils.mqh>
#endif
#ifdef __MQL5__
#include <FXMind\MT5Utils.mqh>
#endif

#include <FXMind\FXMindExpert.mqh>

FXMindExpert* expert = NULL;

void OnChartEvent(const int id,         // Event identifier  
                  const long& lparam,   // Event parameter of long type
                  const double& dparam, // Event parameter of double type
                  const string& sparam) // Event parameter of string type
{
   if (expert != NULL)
      expert.OnEvent(id, lparam, dparam, sparam);

}

//+------------------------------------------------------------------+
//| expert main function                                            |
//+------------------------------------------------------------------+
void OnTick()
{  	
   if (expert != NULL)
   {
      expert.ProcessOrders();
      expert.Draw();
   }
}

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
#ifdef  __MQL4__
   Utils = new MT4Utils();   
#endif   
#ifdef  __MQL5__
   Utils = new MT5Utils();   
#endif   

   expert = new FXMindExpert();
   return expert.Init();
}

void OnTrade()
{
   // TODO: Implement it
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
    if (expert != NULL)
    {
       expert.DeInit(reason);
       DELETE_PTR(expert);   
    }
}

