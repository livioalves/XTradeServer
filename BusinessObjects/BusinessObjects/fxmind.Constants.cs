/**
 * Autogenerated by Thrift Compiler (0.11.0)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.IO;
using Thrift;
using Thrift.Collections;
using System.Runtime.Serialization;

namespace BusinessObjects
{
  public static class fxmindConstants
  {
    /// <summary>
    /// Thrift also lets you define constants for use across languages. Complex
    /// types and structs are specified using JSON notation.
    /// </summary>
    public const double GAP_VALUE = -125;
    public const string MTDATETIMEFORMAT = "yyyy.MM.dd HH:mm";
    public const string MYSQLDATETIMEFORMAT = "yyyy-MM-dd HH:mm:ss";
    public const string SOLRDATETIMEFORMAT = "yyyy-MM-dd'T'HH:mm:ss'Z'";
    public const int SENTIMENTS_FETCH_PERIOD = 100;
    public const short FXMindMQL_PORT = 2010;
    public const short AppService_PORT = 2012;
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
    public const string SETTINGS_PROPERTY_NETSERVERPORT = "FXMind.NETServerPort";
    public const string SETTINGS_PROPERTY_ENDHISTORYDATE = "NewsEvent.EndHistoryDate";
    public const string SETTINGS_PROPERTY_THRIFTPORT = "FXMind.ThriftPort";
    public const string SETTINGS_PROPERTY_INSTALLDIR = "FXMind.InstallDir";
    public const string SETTINGS_PROPERTY_RUNTERMINALUSER = "FXMind.TerminalUser";
    public const string SETTINGS_PROPERTY_MTCOMMONFILES = "Metatrader.CommonFiles";
    public const string SETTINGS_PROPERTY_MQLSOURCEFOLDER = "MQL.Sources";
  }
}
