using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Runtime.Serialization;

namespace BusinessObjects
{
  public static class xtradeConstants
  {
    public const double GAP_VALUE = -125;
    public const string MTDATETIMEFORMAT = "yyyy.MM.dd HH:mm";
    public const string MYSQLDATETIMEFORMAT = "yyyy-MM-dd HH:mm:ss";
    public const string SOLRDATETIMEFORMAT = "yyyy-MM-dd'T'HH:mm:ss'Z'";
    public const int SENTIMENTS_FETCH_PERIOD = 100;
    public const string ANGULAR_DIR = @"../dist";
        
    public const short WebBackend_PORT = 2013;
    public const int FAKE_MAGIC_NUMBER = 1000000;
    public const int TOKEN_LIFETIME_HOURS = 18;

    public const string JOBGROUP_TECHDETAIL = "Technical Details";
    public const string JOBGROUP_OPENPOSRATIO = "Positions Ratio";
    public const string JOBGROUP_EXECRULES = "Run Rules";
    public const string JOBGROUP_NEWS = "News";
    public const string JOBGROUP_THRIFT = "ThriftServer";
    public const string CRON_MANUAL = "0 0 0 1 1 ? 2100";
    public const string PARAMS_SEPARATOR = "|";
    public const string LIST_SEPARATOR = "~";
    public const string GLOBAL_SECTION_NAME = "Global";
    public const string SETTINGS_PROPERTY_BROKERSERVERTIMEZONE = "BrokerServerTimeZone";
    public const string SETTINGS_PROPERTY_PARSEHISTORY = "NewsEvent.ParseHistory";
    public const string SETTINGS_PROPERTY_STARTHISTORYDATE = "NewsEvent.StartHistoryDate";
    public const string SETTINGS_PROPERTY_USERTIMEZONE = "UserTimeZone";
    public const string SETTINGS_PROPERTY_NETSERVERPORT = "XTrade.NETServerPort";
    public const string SETTINGS_PROPERTY_ENDHISTORYDATE = "NewsEvent.EndHistoryDate";
    public const string SETTINGS_PROPERTY_THRIFTPORT = "XTrade.ThriftPort";
    public const string SETTINGS_PROPERTY_INSTALLDIR = "XTrade.InstallDir";
    public const string SETTINGS_PROPERTY_RUNTERMINALUSER = "XTrade.TerminalUser";
    public const string SETTINGS_PROPERTY_MTCOMMONFILES = "Metatrader.CommonFiles";
    public const string SETTINGS_PROPERTY_MQLSOURCEFOLDER = "MQL.Sources";
  }
}
