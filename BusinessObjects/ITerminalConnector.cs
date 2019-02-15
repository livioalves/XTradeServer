﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessObjects
{
    public interface ITerminalConnector : IDisposable
    {
        bool Connect(Terminal toTerminal);
        List<PositionInfo> GetActivePositions();
        void MarketOrder(SignalInfo signal, IExpert adv);

        Dictionary<int, IExpert> GetRunningAdvisers();

        bool IsStopped();
    }
}