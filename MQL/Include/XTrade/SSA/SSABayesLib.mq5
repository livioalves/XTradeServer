//+------------------------------------------------------------------+
//|                                                  SSABayesLib.mq5 |
//|                                Copyright 2016, Korotchenko Roman |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2019, Korotchenko Roman"
#property link      "https://login.mql5.com/ru/users/Solitonic"
#property version   "1.00"

#include <SSA\FileDataPrinter.mqh>  
#include <SSA\CSimpleString.mqh>
#include <SSA\CSimpleCalc.mqh>

#include <SSA\CBayesModelFunction.mqh> 
#include <SSA\CSSATrendPredictor.mqh>  

//static int  writeVectorAsRow_(string path,double &V[], int begIdx, int len, string format);  
  
int  addVectorAsRow_ (int file_handle,double &V[], int begIdx, int len, string format) export //Добавление
{
      return CFileDataPrinter::addVectorAsRow_(file_handle,V, begIdx, len, format);
}

