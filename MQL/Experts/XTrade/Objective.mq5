//+------------------------------------------------------------------+
//|  Expert Adviser Object                             Objective.mq5 |
//|                                 Copyright 2013, Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"

#property strict

#define THRIFT 1

#include <XTrade\TradeExpert.mqh>

TradeExpert* expert = NULL;

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
   string comment = "Objective";

   if ((bool)MQLInfoInteger(MQL_TESTER))
      comment = "Objective Debug";
      
   Utils = CreateUtils((short)ThriftPORT, comment);

   if (CheckPointer(Utils) == POINTER_INVALID)
   {
      Print("FAILED TO CREATE IUtils!!!");
      return INIT_FAILED;
   }

   expert = new TradeExpert();
   return expert.Init();
}


void OnTrade()
{
    if (expert != NULL)
    {
       expert.UpdateOrders();
    }
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

double OnTester()
{
   double resultLoss = TesterStatistics(STAT_LOSSTRADES_AVGCON);
   //double resultLoss = TesterStatistics(STAT_MAX_LOSSTRADE);
   double profitFactor = resultLoss;
   if (resultLoss != 0)
   // double resultLoss = TesterStatistics(STAT_EQUITYMIN);
      profitFactor = TesterStatistics(STAT_PROFIT_FACTOR)/resultLoss;
   return profitFactor;
}

void OnTradeTransaction(const MqlTradeTransaction &trans, 
                        const MqlTradeRequest &request, 
                        const MqlTradeResult &result) 
{
   if ( (Utils.IsTesting()) || Utils.IsVisualMode()) 
       return;
//--- get transaction type as enumeration value  
   ENUM_TRADE_TRANSACTION_TYPE type=(ENUM_TRADE_TRANSACTION_TYPE)trans.type; 
//--- if the transaction is the request handling result, only its name is displayed 
   if( (type == TRADE_TRANSACTION_REQUEST) && (expert != NULL))
   { 
      //--- display the handled request string name 
      //string message = StringFormat("Request: %s \nResult: %s", // EnumToString(type),
      //                               expert.RequestDescription(request),
      //                               expert.TradeResultDescription(result) ); 
      // Utils.Info(message);
      Utils.Trade().UpdateStopLossesTakeProfits(request.action != TRADE_ACTION_SLTP);
      //Utils.Service().NotifyUpdatePositions();
      expert.Draw();
   }
   // else // display the full description for transactions of another type 
   // --- display description of the received transaction in the Journal 
   //    Print("------------TransactionDescription\r\n",expert.TransactionDescription(trans)); 
//--- 
}
