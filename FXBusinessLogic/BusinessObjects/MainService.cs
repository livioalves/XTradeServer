﻿using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using Autofac;
using BusinessObjects;
using DevExpress.Xpo;
using DevExpress.Xpo.DB;
using FXBusinessLogic.fx_mind;
using FXBusinessLogic.Scheduler;
using log4net;
using Microsoft.Win32;
using Quartz;

namespace FXBusinessLogic.BusinessObjects
{
    public class MainService : IMainService
    {
        //public const string MTDATETIMEFORMAT = "yyyy.MM.dd HH:mm";
        public const string NEWSEVENT_HANLDER = "NewsEvent";
        public const string SENTIMENTS_HANLDER = "Sentiments";

        /// <summary>
        /// Settings properties
        /// </summary>
        public const string SETTINGS_PROPERTY_THRIFTPORT = "FXMind.ThriftPort";
        public const string SETTINGS_PROPERTY_NETSERVERPORT = "FXMind.NETServerPort";
        public const string SETTINGS_APPREGKEY = @"SOFTWARE\\FXMind";
        //public const string SETTINGS_TEMINAL_MONITOR_CRON = "0 */2 * ? * MON-FRI *"; // @"0 */2 * ? * *"; // run every 5 minutes.

        //public const string MYSQLDATETIMEFORMAT = "yyyy-MM-dd HH:mm:ss";
        public const int SENTIMENTS_FETCH_PERIOD = 100;
        private static readonly ILog log = LogManager.GetLogger(typeof(MainService));
        public static MainService thisGlobal;
        private static int isDebug = -1;
        private SchedulerService _gSchedulerService;
        private INotificationUi _ui;
        protected TimeZoneInfo BrokerTimeZoneInfo;
        private bool Initialized;

        public static string AssemblyDirectory
        {
            get
            {
                string codeBase = Assembly.GetExecutingAssembly().CodeBase;
                UriBuilder uri = new UriBuilder(codeBase);
                string path = Uri.UnescapeDataString(uri.Path);
                return Path.GetDirectoryName(path);
            }
        }

        public static string RegistryInstallDir
        {
            get
            {
                string result = AssemblyDirectory;
                try
                {
                    RegistryKey rk = Registry.LocalMachine.OpenSubKey(SETTINGS_APPREGKEY, false);
                    if (rk == null)
                    {
                        rk = Registry.LocalMachine.CreateSubKey(SETTINGS_APPREGKEY, true, RegistryOptions.None);
                        rk.SetValue("InstallDir", result);
                    } else
                    {
                        result = rk.GetValue("InstallDir")?.ToString();
                    }
                }
                catch (Exception e)
                {
                    log.Error("ERROR FROM RegistryInstallDir: " + e);
                }
                return result;
            }
        }

        public static string MTTerminalUserName
        {
            get
            {
                string result = WindowsIdentity.GetCurrent().Name;
                try
                {
                    RegistryKey rk = Registry.LocalMachine.OpenSubKey(SETTINGS_APPREGKEY, false);
                    if (rk == null)
                    {
                        rk = Registry.LocalMachine.CreateSubKey(SETTINGS_APPREGKEY, true, RegistryOptions.None);
                        rk.SetValue("MTTerminalUserName", result);
                    }
                    else
                    {
                        result = rk.GetValue("RunMTTerminalUserName")?.ToString();
                    }
                }
                catch (Exception e)
                {
                    log.Error("ERROR FROM RunMTTerminalUserName: " + e);
                }
                return result;
            }
        }


        public MainService()
        {
            RegisterContainer();
            Initialized = false;
            thisGlobal = this;
        }

        public List<Currency> GetCurrencies()
        {
            Session session = FXConnectionHelper.GetNewSession();
            var currenciesDb = new XPCollection<DBCurrency>(session);
            List<Currency> list = new List<Currency>();
            foreach (var dbCurrency in currenciesDb)
            {
                var curr = new Currency();
                curr.ID = dbCurrency.ID;
                curr.Name = dbCurrency.Name;
                curr.Enabled = dbCurrency.Enabled;
                list.Add(curr);
            }
            session.Disconnect();
            return list;
        }

        public List<TechIndicator> GetIndicators()
        {
            Session session = FXConnectionHelper.GetNewSession();
            var techIndiDb = new XPCollection<DBTechIndicator>(session);
            List<TechIndicator> list = new List<TechIndicator>();
            foreach (var dbI in techIndiDb)
            {
                var ti = new TechIndicator();
                ti.ID = dbI.ID;
                ti.IndicatorName = dbI.IndicatorName;
                ti.Enabled = dbI.Enabled;
                list.Add(ti);
            }
            session.Disconnect();
            return list;
        }

        public void SaveCurrency(Currency currency)
        {
            Session session = FXConnectionHelper.GetNewSession();
            var cQuery = new XPQuery<DBCurrency>(session);
            IQueryable<DBCurrency> curs = from c in cQuery
                where c.ID == currency.ID
                select c;
            DBCurrency gvar = null;
            if (curs.Any())
            {
                gvar = curs.First();
                gvar.Enabled = currency.Enabled;
            }
            else
            {
                gvar = new DBCurrency(session);
                gvar.Name = currency.Name;
                gvar.Enabled = currency.Enabled;
            }

            gvar.Save();
            session.Disconnect();
        }

        public void SaveIndicator(TechIndicator i)
        {
            Session session = FXConnectionHelper.GetNewSession();
            var cQuery = new XPQuery<DBTechIndicator>(session);
            IQueryable<DBTechIndicator> curs = from c in cQuery
                where c.ID == i.ID
                select c;
            DBTechIndicator gvar = null;
            if (curs.Any())
            {
                gvar = curs.First();
                gvar.Enabled = i.Enabled;
            }
            else
            {
                gvar = new DBTechIndicator(session);
                gvar.IndicatorName = i.IndicatorName;
                gvar.Enabled = i.Enabled;
            }

            gvar.Save();
            session.Disconnect();
        }

        public IContainer Container { get; private set; }


        public INotificationUi GetUi()
        {
            return _ui;
        }

        protected void RegistryInit()
        {

            log.Info("Registry InstallDir: " + RegistryInstallDir);
            // TODO: implement registry settings read/write
        }

        public void Init(INotificationUi ui)
        {
            if (Initialized)
                return;
            _ui = ui;

            RegistryInit();

            //FXConnectionHelper.Connect(null);

            BrokerTimeZoneInfo = GetBrokerTimeZone();

            InitScheduler(true);

            Initialized = true;
        }

        public bool InitScheduler(bool serverMode /*unused*/)
        {
            if (_gSchedulerService == null)
                _gSchedulerService = Container.Resolve<SchedulerService>(new NamedParameter("ui", _ui));
            return _gSchedulerService.Initialize();
        }


        public TimeZoneInfo GetBrokerTimeZone()
        {
            if (BrokerTimeZoneInfo == null)
            {
                BrokerTimeZoneInfo = GetTimeZoneFromString("BrokerServerTimeZone");
            }
            return BrokerTimeZoneInfo;
        }

        public string GetGlobalProp(string name)
        {
            Session session = FXConnectionHelper.GetNewSession();
            var res = FXMindHelpers.GetGlobalVar(session, name);
            session.Disconnect();
            return res;
        }

        public void SetGlobalProp(string name, string value)
        {
            Session session = FXConnectionHelper.GetNewSession();
            FXMindHelpers.SetGlobalVar(session, name, value);
            session.Disconnect();
        }


        public List<double> iCurrencyStrengthAll(string currencyStr, List<string> brokerDates, int iTimeframe)
        {
            var resultDoubles = new List<double>();

            int dbTimeFrame = iTimeFrameToDBTimeframe(iTimeframe);
            if (dbTimeFrame == -1)
                return resultDoubles;

            // new session should be created for crossthread issues
            Session session = FXConnectionHelper.GetNewSession();

            const string queryStrInterval =
                @"SELECT TD.SummaryId, TD.IndicatorId, TD.Action, TD.Value, TS.ID, TS.SymbolId,  TS.Timeframe, TS.Date, S.Name, S.C1, S.C2
            FROM TechDetail TD
            INNER JOIN TechSummary TS ON TD.SummaryId = TS.ID
            INNER JOIN TechIndicator TI ON TD.IndicatorId = TI.ID
            INNER JOIN Symbol S ON TS.SymbolId = S.ID
            WHERE (TS.Type = 1) AND (TS.Date >= @fr_dt) AND (TS.Date <= @to_dt) AND (TS.Timeframe=@tf) AND (TI.Enabled=1) AND ((S.Name LIKE @curr) AND (S.Use4Tech=1))
            ORDER BY TS.Date DESC";

            foreach (string brokerDate in brokerDates)
            {
                DateTime from;
                DateTime.TryParseExact(brokerDate, fxmindConstants.MTDATETIMEFORMAT,
                    CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.None, out from);

                from = TimeZoneInfo.ConvertTimeToUtc(from, BrokerTimeZoneInfo);
                DateTime to = from;
                switch (dbTimeFrame)
                {
                    case 1:
                        to = to.AddMinutes(1);
                        break;
                    case 2:
                        to = to.AddMinutes(5);
                        break;
                    case 3:
                        to = to.AddMinutes(15);
                        break;
                    case 4:
                        to = to.AddMinutes(30);
                        break;
                    case 5:
                        to = to.AddHours(1);
                        break;
                    case 6:
                        to = to.AddHours(5);
                        break;
                    case 7:
                        to = to.AddDays(1);
                        break;
                    case 8:
                        to = to.AddMonths(1);
                        break;
                }

                string[] paramnames = {"fr_dt", "to_dt", "tf", "curr"};
                object[] parameters =
                {
                    from.ToString(fxmindConstants.MYSQLDATETIMEFORMAT),
                    to.ToString(fxmindConstants.MYSQLDATETIMEFORMAT), dbTimeFrame, "%" + currencyStr + "%"
                };
                SelectedData data = session.ExecuteQuery(queryStrInterval, paramnames, parameters);
                int count = data.ResultSet[0].Rows.Count();
                int TFcnt = 0;
                var multiplier = new decimal(1.0);
                var result = new decimal(0.0);
                var ProcessedSymbols = new HashSet<int>();
                foreach (SelectStatementResultRow row in data.ResultSet[0].Rows)
                {
                    var symbol = (int) row.Values[5];
                    if (ProcessedSymbols.Contains(symbol))
                        continue;
                    ProcessedSymbols.Add(symbol);
                    if (row.Values[10].Equals(currencyStr))
                        multiplier = new decimal(-1.0);
                    else
                        multiplier = new decimal(1.0);
                    var actionValue = (short) row.Values[2];
                    //var tf = (Byte)row.Values[6];
                    result += actionValue * multiplier;
                    TFcnt++;
                }

                if (TFcnt > 0)
                {
                    result = 100 * result / TFcnt;
                    resultDoubles.Add((double) result);
                }
                else
                {
                    resultDoubles.Add(fxmindConstants.GAP_VALUE);
                }
            }

            session.Dispose();
            return resultDoubles;
        }

        /*
        public string GetActionString(int actionId)
        {
            switch (actionId)
            {
                case 2:
                    return "STRONG BUY";
                case 1:
                    return "BUY";
                case 0:
                    return "NEUTRAL";
                case -1:
                    return "SELL";
                case -2:
                    return "STRONG SELL";
                default:
                    return "ERROR";
            }
        }*/

        public List<ScheduledJob> GetAllJobsList()
        {
            return SchedulerService.GetAllJobsList();
        }

        public Dictionary<string, ScheduledJob> GetRunningJobs()
        {
            return SchedulerService.GetRunningJobs();
        }

        public DateTime? GetJobNextTime(string group, string name)
        {
            return SchedulerService.GetJobNextTime(group, name);
        }

        public DateTime? GetJobPrevTime(string group, string name)
        {
            return SchedulerService.GetJobPrevTime(group, name);
        }

        #region DBJobs
        public IEnumerable<DBJobs> GetDBActiveJobsList(Session session)
        {

            var jobsQuery = new XPQuery<DBJobs>(session);
            IQueryable<DBJobs> jobs = from c in jobsQuery
                                           where c.DISABLED == 0
                                           select c;

            return jobs;
        }

        public void UnsheduleJobs(IEnumerable<JobKey> jobs)
        {
            foreach (var job in jobs)
                SchedulerService.removeJobTriggers(job);
        }

        public bool DeleteJob(JobKey job)
        {
             return SchedulerService.sched.DeleteJob(job).Result;
        }

        #endregion

        public void Dispose()
        {
            if (_gSchedulerService != null)
                _gSchedulerService.Shutdown();
        }

        public void PauseScheduler()
        {
            SchedulerService.sched.PauseAll();
        }

        public void ResumeScheduler()
        {
            SchedulerService.sched.ResumeAll();
        }

        public bool GetNextNewsEvent(DateTime date, string symbolStr, byte minImportance, ref NewsEventInfo eventInfo)
        {
            Session session = FXConnectionHelper.GetNewSession();
            bool result = false;
            try
            {
                eventInfo = null;
                // new session should be created for crossthread issues

                BrokerTimeZoneInfo = GetBrokerTimeZone();

                const string queryStrInterval =
                    @"SELECT C.Name 
	                ,NE.HappenTime
                    ,NE.Name
                    ,NE.Raised
                    ,NE.Importance
                FROM NewsEvent NE
                INNER JOIN Currency C ON NE.CurrencyId = C.ID
                WHERE (C.Name=@c1 OR C.Name=@c2) AND (NE.HappenTime >= @fr_dt) AND (NE.HappenTime <= @to_dt) AND (NE.Importance >= @imp) ORDER BY NE.HappenTime ASC, NE.Importance DESC";

                string C1 = symbolStr.Substring(0, 3);
                string C2 = C1;
                if (symbolStr.Length == 6)
                    C2 = symbolStr.Substring(3, 3);

                DateTime from = TimeZoneInfo.ConvertTimeToUtc(date, BrokerTimeZoneInfo);
                // date.AddHours(-BrokerTimeZoneInfo.BaseUtcOffset.Hours);
                DateTime to = from.AddDays(1); //.AddMinutes(beforeIntervalMinutes);
                //to = to.AddHours(-BrokerTimeZoneInfo.BaseUtcOffset.Hours);

                string[] paramnames = {"c1", "c2", "fr_dt", "to_dt", "imp"};
                object[] parameters =
                {
                    C1, C2, from.ToString(fxmindConstants.MYSQLDATETIMEFORMAT),
                    to.ToString(fxmindConstants.MYSQLDATETIMEFORMAT), minImportance
                };
                SelectedData data = session.ExecuteQuery(queryStrInterval, paramnames, parameters);

                int count = data.ResultSet[0].Rows.Count();
                if (count <= 0)
                {
                    eventInfo = null;
                    return false;
                }

                foreach (SelectStatementResultRow row in data.ResultSet[0].Rows)
                {
                    eventInfo = new NewsEventInfo();
                    eventInfo.Currency = (string)row.Values[0];
                    DateTime raiseDT = (DateTime)row.Values[1];
                    raiseDT = TimeZoneInfo.ConvertTimeFromUtc(raiseDT,
                        BrokerTimeZoneInfo);
                    eventInfo.RaiseDateTime = raiseDT.ToString(fxmindConstants.MTDATETIMEFORMAT);
                    //eventInfo.RaiseDateTime.AddHours(BrokerTimeZoneInfo.BaseUtcOffset.Hours);
                    eventInfo.Name = (string)row.Values[2];
                    byte imp = (byte)row.Values[4];
                    eventInfo.Importance = (sbyte)imp;
                    break;
                }
                result = true;
            }
            catch (Exception e)
            {
                log.Error(e.ToString());
            }
            finally
            {
                session.Disconnect();
                session.Dispose();
            }

            return result;
        }

        public void GetAverageLastGlobalSentiments(DateTime date, string symbolName, out double longPos,
            out double shortPos)
        {
            longPos = -1;
            shortPos = -1;
            Session session = FXConnectionHelper.GetNewSession();
            try
            {
                BrokerTimeZoneInfo = GetBrokerTimeZone();
                if (symbolName.Length == 6)
                    symbolName = symbolName.Insert(3, "/");
                DBSymbol dbsym = FXMindHelpers.getSymbolID(session, symbolName);
                if (dbsym == null)
                    return;

                DateTime to = TimeZoneInfo.ConvertTimeToUtc(date, BrokerTimeZoneInfo);
                DateTime from = to.AddMinutes(-SENTIMENTS_FETCH_PERIOD);
                const string queryStrInterval = @"SELECT LongRatio, ShortRatio, SiteID FROM OpenPosRatio
                                                WHERE (SymbolID=@symID) AND (ParseTime >= @fr_dt) AND (ParseTime <= @to_dt) 
                                                ORDER BY ParseTime DESC";

                string[] paramnames = {"symID", "fr_dt", "to_dt"};
                object[] parameters =
                {
                    dbsym.ID, from.ToString(fxmindConstants.MYSQLDATETIMEFORMAT),
                    to.ToString(fxmindConstants.MYSQLDATETIMEFORMAT)
                };
                SelectedData data = session.ExecuteQuery(queryStrInterval, paramnames, parameters);

                int count = data.ResultSet[0].Rows.Count();
                if (count > 0)
                {
                    int cnt = 0;
                    double valLong = 0;
                    double valShort = 0;
                    foreach (SelectStatementResultRow row in data.ResultSet[0].Rows)
                    {
                        valLong += (double) row.Values[0];
                        valShort += (double) row.Values[1];
                        cnt++;
                    }

                    longPos = valLong / cnt;
                    shortPos = valShort / cnt;
                }

                //INotificationUi ui = GetUi();
                //if (ui != null)
                //    if (IsDebug())
                //        ui.LogStatus("GetLastAverageGlobalSentiments for " + symbolName + " : " + longPos + ", " +
                //                     shortPos);
            }
            catch (Exception e)
            {
                log.Error(e.ToString());
            }
            finally
            {
                session.Disconnect();
                session.Dispose();
            }
        }

        public bool IsDebug()
        {
            if (isDebug == -1)
            {
                Assembly assembly = Assembly.GetExecutingAssembly();
                bool isDebugBuild = assembly.GetCustomAttributes(false).OfType<DebuggableAttribute>()
                    .Select(attr => attr.IsJITTrackingEnabled).FirstOrDefault();
                if (isDebugBuild)
                {
                    isDebug = 1;
                    return true;
                }

                isDebug = 0;
                return false;
            }

            return isDebug > 0 ? true : false;
        }

        public List<double> iGlobalSentimentsArray(string symbolName, List<string> brokerDates, int siteId)
        {
            var resList = new List<double>();
            Session session = FXConnectionHelper.GetNewSession();
            try
            {
                if (symbolName.Length == 6)
                    symbolName = symbolName.Insert(3, "/");
                DBSymbol dbsym = FXMindHelpers.getSymbolID(session, symbolName);
                if (dbsym == null)
                    return resList;
                string queryStrInterval;
                var paramnames = new string[] { };
                if (siteId == 0)
                {
                    queryStrInterval = @"SELECT LongRatio, ShortRatio, SiteID FROM OpenPosRatio
                                                    WHERE (SymbolID=@symID) AND (ParseTime >= @fr_dt) AND (ParseTime <= @to_dt) 
                                                    ORDER BY ParseTime DESC";
                    paramnames = new[] { "symID", "fr_dt", "to_dt" };
                }
                else
                {
                    queryStrInterval = @"SELECT LongRatio, ShortRatio FROM OpenPosRatio
                                                WHERE (SymbolID=@symID) AND (ParseTime >= @fr_dt) AND (ParseTime <= @to_dt) AND (SiteID = @siteID)
                                                ORDER BY ParseTime ASC";
                    paramnames = new[] { "symID", "fr_dt", "to_dt", "siteID" };
                }

                foreach (string brokerDate in brokerDates)
                {
                    DateTime date;
                    DateTime.TryParseExact(brokerDate, fxmindConstants.MTDATETIMEFORMAT,
                        CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.None, out date);

                    date = TimeZoneInfo.ConvertTimeToUtc(date, BrokerTimeZoneInfo);
                    DateTime hourPlus = date;
                    hourPlus = hourPlus.AddHours(1);
                    object[] parameters = { };
                    if (siteId == 0)
                        parameters = new object[]
                        {
                            dbsym.ID, date.ToString(fxmindConstants.MYSQLDATETIMEFORMAT),
                            hourPlus.ToString(fxmindConstants.MYSQLDATETIMEFORMAT)
                        };
                    else
                        parameters = new object[]
                        {
                            dbsym.ID, date.ToString(fxmindConstants.MYSQLDATETIMEFORMAT),
                            hourPlus.ToString(fxmindConstants.MYSQLDATETIMEFORMAT), siteId
                        };
                    SelectedData data = session.ExecuteQuery(queryStrInterval, paramnames, parameters);
                    int count = data.ResultSet[0].Rows.Count();
                    if (count == 0)
                    {
                        resList.Add(fxmindConstants.GAP_VALUE);
                    }
                    else
                    {
                        int cnt = 0;
                        double valLong = 0;
                        //double valShort = 0;
                        foreach (SelectStatementResultRow row in data.ResultSet[0].Rows)
                        {
                            valLong += (double)row.Values[0];
                            //valShort += (double) row.Values[1];
                            cnt++;
                        }

                        resList.Add(valLong / cnt);
                    }
                }
            }
            catch (Exception e)
            {
                log.Error(e.ToString());
            }
            finally
            {

                session.Disconnect();
                session.Dispose();
            }
            return resList;
        }

        protected void testDate(string date)
        {
            DateTime from;
            DateTime.TryParseExact(date, fxmindConstants.MTDATETIMEFORMAT,
                CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.None, out from);
            NewsEventInfo info = new NewsEventInfo();
            GetNextNewsEvent(from, "EURUSD", 1, ref info);
        }

        private void RegisterContainer()
        {
            var builder = new ContainerBuilder();
            builder.RegisterType<SchedulerService>().AsSelf().SingleInstance().WithParameter("ui", _ui);
            builder.RegisterType<MainService>().As<IMainService>().SingleInstance();
            Container = builder.Build();
        }

        protected TimeZoneInfo GetTimeZoneFromString(string propName)
        {
            string strTimeZone = GetGlobalProp(propName);
            ReadOnlyCollection<TimeZoneInfo> tz = TimeZoneInfo.GetSystemTimeZones();
            foreach (TimeZoneInfo tzi in tz)
                if (tzi.StandardName.Equals(strTimeZone))
                    return tzi;
            return null;
        }

        private double CalcCS4CurrencyLast(Session session, string currencyName, int Timeframe)
        {
            const string queryStrInterval =
                @"SELECT TOP 100 TD.SummaryId, TD.IndicatorId, TD.Action, TD.Value, TS.ID, TS.SymbolId,  TS.Timeframe, TS.Date, S.Name, S.C1, S.C2
                FROM TechDetail TD
                INNER JOIN TechSummary TS ON TD.SummaryId = TS.ID
                INNER JOIN TechIndicator TI ON TD.IndicatorId = TI.ID
                INNER JOIN Symbol S ON TS.SymbolId = S.ID
                WHERE (TS.Type = 1) AND (TS.Date >= '{0}') AND (TS.Date <= '{1}') AND (TS.Timeframe={2}) AND (TI.Enabled = 1) AND ((S.Name  LIKE '%{3}%') AND (S.Use4Tech = 1))
                ORDER BY TS.Date DESC";

            DateTime dayBefore = DateTime.UtcNow.AddDays(-3);
            DateTime dayToday = DateTime.UtcNow;
            string resultQuery = string.Format(queryStrInterval, dayBefore, dayToday, Timeframe, currencyName);
            SelectedData data = session.ExecuteQuery(resultQuery);

            int count = data.ResultSet[0].Rows.Count();
            int TFcnt = 0;
            double multiplier = 1.0;
            double result = 0.0;
            var ProcessedSymbols = new HashSet<int>();
            foreach (SelectStatementResultRow row in data.ResultSet[0].Rows)
            {
                var symbol = (int) row.Values[5];
                if (ProcessedSymbols.Contains(symbol))
                    continue;
                ProcessedSymbols.Add(symbol);
                if (row.Values[10].Equals(currencyName))
                    multiplier = -1.0;
                else
                    multiplier = 1.0;
                var actionValue = (short) row.Values[2];
                //var tf = (Byte)row.Values[6];
                result += actionValue * multiplier;
                TFcnt++;
            }

            if (TFcnt > 0)
                result = 100 * result / TFcnt;
            return result;
        }

        private int iTimeFrameToDBTimeframe(int iTimeframe)
        {
            // -1 means not supported
            switch (iTimeframe)
            {
                case 1: //Min1
                    return 1;
                case 5: //Min5
                    return 2;
                case 15: //Min15
                    return 3;
                case 30: //Min30
                    return 4;
                case 60: //Hour
                    return 5;
                case 240: // Hour4 Hour5
                    return 6;
                case 1440: // Daily
                    return 7;
                case 10080: // Weekly not supported
                    return -1;
                case 43200: //Monthly
                    return 8;
            }

            return -1;
        }

        #region Jobs

        public void RunJobNow(string group, string name)
        {
            SchedulerService.RunJobNow(new JobKey(name, group));
        }

        public string GetJobProp(string group, string name, string prop)
        {
            return SchedulerService.GetJobProp(group, name, prop);
        }

        public void SetJobCronSchedule(string group, string name, string cron)
        {
            SchedulerService.SetJobCronSchedule(group, name, cron);
        }

        #endregion
    }
}