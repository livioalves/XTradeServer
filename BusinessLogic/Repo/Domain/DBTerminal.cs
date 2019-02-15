using System;
using System.Text;
using System.Collections.Generic;


namespace BusinessLogic.Repo
{
    public class DBTerminal : BaseEntity<DBTerminal>
    {
        public virtual int Id { get; set; }
        public virtual DBAccount Account { get; set; }
        public virtual int? Accountnumber { get; set; }
        public virtual string Broker { get; set; }
        public virtual string Fullpath { get; set; }
        public virtual string Codebase { get; set; }
        public virtual bool Disabled { get; set; }
        public virtual bool Demo { get; set; }
        public virtual bool Stopped { get; set; }
    }
}