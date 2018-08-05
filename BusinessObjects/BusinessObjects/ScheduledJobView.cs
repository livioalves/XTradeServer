﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using BusinessObjects;

namespace BusinessObjects
{
    public class ScheduledJobView 
    {
        public int ID {  get; set;}
        public DateTime PrevDate { get; set; }
        public DateTime NextDate { get; set; }

        public string Group { get; set; }

        public string Name
        {
            get;
            set;
        }

        public string Schedule
        {
            get;
            set;
        }

        public bool IsRunning
        {
            get;
            set;
        }

        public string Log
        {
            get;
            set;
        }

    }
}