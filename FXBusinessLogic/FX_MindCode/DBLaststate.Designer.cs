﻿//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------
using System;
using DevExpress.Xpo;
using DevExpress.Data.Filtering;
using System.Collections.Generic;
using System.ComponentModel;
namespace FXBusinessLogic.fx_mind
{

    [NonPersistent]
    public partial class DBLaststate : XPLiteObject
    {
        int fWALLET_ID;
        public int WALLET_ID
        {
            get { return fWALLET_ID; }
            set { SetPropertyValue<int>(nameof(WALLET_ID), ref fWALLET_ID, value); }
        }
        string fNAME;
        [Size(127)]
        public string NAME
        {
            get { return fNAME; }
            set { SetPropertyValue<string>(nameof(NAME), ref fNAME, value); }
        }
        decimal fBALANCE;
        public decimal BALANCE
        {
            get { return fBALANCE; }
            set { SetPropertyValue<decimal>(nameof(BALANCE), ref fBALANCE, value); }
        }
        DateTime fDATE;
        public DateTime DATE
        {
            get { return fDATE; }
            set { SetPropertyValue<DateTime>(nameof(DATE), ref fDATE, value); }
        }
    }

}
