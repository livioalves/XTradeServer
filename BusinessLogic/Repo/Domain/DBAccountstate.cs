using System;
using System.Text;
using System.Collections.Generic;


namespace BusinessLogic.Repo {
    
    public class DBAccountstate : BaseEntity<DBAccountstate> {
        public virtual int Id { get; set; }
        public virtual DBAccount Account { get; set; }
        public virtual DateTime Date { get; set; }
        public virtual decimal Balance { get; set; }
        public virtual string Comment { get; set; }
        public virtual string Formula { get; set; }
    }
}
