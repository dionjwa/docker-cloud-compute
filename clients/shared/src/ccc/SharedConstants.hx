package ccc;

class SharedConstants
{
	/* Redis */
	inline public static var SEP = ':';
	inline public static var CCC_PREFIX = 'ccc${SEP}';

	public static var PREFIX_TURBO_JOB :String = '${CCC_PREFIX}turbojob${SEP}';
	inline public static var JOBSPREFIX :String = '${CCC_PREFIX}jobs${SEP}';
	inline public static var PREFIX_STATS :String = '${JOBSPREFIX}stats${SEP}';

	public static var REDIS_KEY_ZSET_PREFIX_WORKER_JOBS_ACTIVE = '${JOBSPREFIX}zset${SEP}worker_jobs_active${SEP}';//<JobId>
	public static var REDIS_KEY_HASH_JOB_STATS = '${PREFIX_STATS}hash${SEP}job';
	public static var REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS = '${CCC_PREFIX}worker${SEP}health_status${SEP}';//<WorkerHealthStatus>
	public static var REDIS_MACHINE_LAST_STATUS = '${CCC_PREFIX}worker${SEP}hash${SEP}status';//<MachineId, WorkerStatus>
	/* Last finished job time for queues, used by lambda to control scaling down */
	public static var REDIS_HASH_TIME_LAST_JOB_FINISHED = '${JOBSPREFIX}hash${SEP}last_job_finished_time';//<BullQueueName, Float>
}