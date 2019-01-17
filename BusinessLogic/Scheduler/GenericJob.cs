using System;
using System.Threading.Tasks;
using BusinessLogic.BusinessObjects;
using BusinessObjects;
using Quartz;
using Autofac;

namespace BusinessLogic.Scheduler
{
    public abstract class GenericJob : IJob
    {
        protected readonly IWebLog log;

        private DateTimeOffset runTime;
        protected string strMessage;
        // protected bool bShouldBeStopped;

        protected GenericJob()
        {
            log = MainService.thisGlobal.Container.Resolve<IWebLog>();
            // bShouldBeStopped = false;
        }

        public void SetMessage(string message)
        {
            strMessage = message;
        }

        public bool Begin(IJobExecutionContext context)
        {
            runTime = SystemTime.UtcNow();
            JobKey key = context.JobDetail.Key;
            return false;
        }

        public async void Exit(IJobExecutionContext context)
        {
            DateTimeOffset now = SystemTime.UtcNow();
            TimeSpan duration = now - runTime;
            strMessage += ". For " + (long) duration.TotalMilliseconds + " ms. At " +
                          now.ToString(xtradeConstants.MTDATETIMEFORMAT) + " GMT";
            SchedulerService.LogJob(context, strMessage);
            if ((log != null) && !String.IsNullOrEmpty(strMessage))
                log.Log(strMessage);
            await Task.CompletedTask;
        }

        public abstract Task Execute(IJobExecutionContext context);
    }
}