package ccc.scaling;

typedef TestJobArgs = {
	var count :Int;
	var duration :Int;
	var name :String;
}

class ScalingTests
	extends PromiseTest
{
	@inject public var redis :RedisClient;
	@inject public var docker :Docker;
	@inject public var lambda :LambdaScaling;

	@timeout(120000)
	public function testWorkerLifecycleEvents() :Promise<Bool>
	{
		Log.debug({event:'testWorkerLifecycleEvents'});
		var workerId :MachineId;
		return Promise.promise(true)
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents killAllWorkers'});
				return killAllWorkers();
			})
			.pipe(lambda.traceJson())
			.thenWait(5000)//Cloud build systems time out all the time
			.pipe(lambda.traceJson())
			//Start with a single worker
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents setState'});
				trace('testWorkerLifecycleEvents setState');
				return ScalingCommands.setState({
					MinSize: 1,
					MaxSize: 2,
					DesiredCapacity: 1
				})
				.thenWait(3000);
			})
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents getAllDockerWorkerIds'});
				return ScalingCommands.getAllDockerWorkerIds()
					.then(function(workers) {
						assertEquals(workers.length, 1);
						workerId = workers[0];
						return true;
					});
			})
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents sendCommandToAllWorkers'});
				return WorkerStateRedis.sendCommandToAllWorkers(WorkerUpdateCommand.PauseHealthCheck);
			})
			.thenWait(1000)
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents Validate health'});
				return WorkerStreams.until(redis, workerId, function(workerState) {
					return workerState.status == WorkerStatus.OK;
				}, 9000);
			})
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents getHealthStatus'});
				return WorkerStateRedis.getHealthStatus(workerId)
					.then(function(healthStatus) {
						assertEquals(healthStatus, WorkerHealthStatus.OK);
						return true;
					})
					.pipe(function(_) {
						return WorkerStateRedis.getStatus(workerId)
							.then(function(status) {
								assertEquals(status, WorkerStatus.OK);
								return true;
							});
					});
			})
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'testWorkerLifecycleEvents Validate when unhealthy'});
				return WorkerStateRedis.setHealthStatus(workerId, WorkerHealthStatus.BAD_DiskFull)
					.pipe(function(_) {
						return WorkerStateRedis.get(workerId)
							.then(function(blob) {
								Log.debug({event:'After setting unhealthy, status=${blob.status}'});
								assertEquals(blob.status, WorkerStatus.UNHEALTHY);
								assertEquals(blob.statusHealth, WorkerHealthStatus.BAD_DiskFull);
								return true;
							});
					});
			})
			.pipe(lambda.traceJson())
			.pipe(function(_) {
				Log.debug({event:'Scale down, should terminate worker'});
				return lambda.scaleDown(AsgType.CPU)
					.thenWait(1000)
					.pipe(function(_) {
						return WorkerStateRedis.get(workerId)
							.then(function(blob) {
								Log.debug('After setting unhealthy, status=${blob.status}');
								assertEquals(blob.status, WorkerStatus.REMOVED);
								Log.debug('blob.statusHealth=${blob.statusHealth}');
								assertEquals(blob.statusHealth, WorkerHealthStatus.BAD_DiskFull);
								return true;
							});
					})
					.pipe(lambda.traceJson())
					.pipe(function(_) {
						return ScalingCommands.getAllDockerWorkerIds()
							.then(function(workers) {
								assertEquals(workers.length, 0);
								return true;
							});
					})
					.pipe(function(_) {
						return WorkerStateRedis.getAllActiveWorkers()
							.then(function(workers) {
								assertEquals(workers.length, 0);
								return true;
							});
					});
			});
	}

	@timeout(10000)
	public function testCreateWorker() :Promise<Bool>
	{
		var rpcUrl = '${ScalingServerConfig.DCC}/${Type.enumConstructor(CCCVersion.v1)}';
		var proxy = ccc.compute.client.util.ProxyTools.getProxy(rpcUrl);
		return Promise.promise(true)
			.pipe(function(_) {
				return killAllWorkers();
			})
			.pipe(function(_) {
				return ScalingCommands.createWorker();
			})
			//Wait until a worker is ready
			.pipe(function(_) {
				return RetryPromise.retryRegular(function() {
					return proxy.status()
						.then(function(status) {
							assertTrue(status.workers.length > 0);
							return true;
						});
				}, 20, 1000);
			})
			.pipe(function(_) {
				return killAllWorkers()
					.pipe(function(_) {
						return ScalingCommands.getTestWorkers()
							.then(function(workers) {
								assertEquals(workers.length, 0);
								return true;
							});
					});
			});
	}

	@timeout(30000)
	public function testScalingCommands() :Promise<Bool>
	{
		var desired = 3;
		return Promise.promise(true)
			//Delete existing workers
			.pipe(function(_) {
				return killAllWorkers();
			})
			.pipe(function(_) {
				return ScalingCommands.setState({
					MinSize: 1,
					MaxSize: 4,
					DesiredCapacity: desired
				})
				.thenWait(6000)
				.pipe(function(_) {
					return ScalingCommands.getAllDockerWorkerIds()
						.then(function(workers) {
							assertEquals(workers.length, desired);
							return true;
						});
				});
			})
			.pipe(function(_) {
				return ScalingCommands.setState({
					MinSize: 0,
					MaxSize: 4,
					DesiredCapacity: 0
				})
				.thenWait(2000)
				.pipe(function(_) {
					return ScalingCommands.getAllDockerWorkerIds()
						.then(function(workers) {
							assertEquals(workers.length, 0);
							return true;
						});
				});
			})
			.thenTrue();
	}

	@timeout(120000)
	public function testScaleDownLambda() :Promise<Bool>
	{
		return Promise.promise(true)
			.pipe(function(_) {
				return killAllWorkers();
			})
			.pipe(function(_) {
				// traceCyan('Ensure a single worker');
				return ScalingCommands.setState({
					MinSize: 1,
					MaxSize: 4,
					DesiredCapacity: 3
				})
				.thenWait(3000)
				.pipe(function(_) {
					return ScalingCommands.getAllDockerWorkerIds()
						.then(function(workers) {
							// traceCyan('Ensure 3 workers');
							assertEquals(workers.length, 3);
							return true;
						});
				})
				.pipe(function(_) {
					// traceCyan('Make all workers do a health check');
					return WorkerStateRedis.sendCommandToAllWorkers(WorkerUpdateCommand.HealthCheck)
						.thenWait(500);
				});
			})
			.pipe(function(_) {
				return JobStateTools.cancelAllJobs();
			})
			.thenWait(500)
			.pipe(function(_) {
				// traceCyan('Scale down');
				return lambda.scaleDown(AsgType.CPU)
					.then(function(result) {
						trace(result);
						return true;
					})
					.thenTrue();
			})
			.thenWait(4000)
			.pipe(function(_) {
				// traceCyan('Now check the number of workers, should be 1');
				return ScalingCommands.getAllDockerWorkerIds()
					.then(function(workers) {
						// traceCyan('Final workers after job submission=$workers');
						assertEquals(workers.length, 1);
						return true;
					});
			})
			.thenWait(3000)
			.pipe(function(_) {
				// traceCyan('Scale down again, should be idempotent');
				return lambda.scaleDown(AsgType.CPU).thenTrue()
					.thenWait(1000)
					.pipe(function(_) {
						return ScalingCommands.getAllDockerWorkerIds()
							.then(function(workers) {
								// traceCyan('Final workers after job submission=$workers');
								assertEquals(workers.length, 1);
								return true;
							});
					});
			})
			.thenTrue();
	}

	@timeout(120000)
	public function testScaleUpLambda() :Promise<Bool>
	{
		var rpcUrl = '${ScalingServerConfig.DCC}/${Type.enumConstructor(CCCVersion.v1)}';
		var proxy = ccc.compute.client.util.ProxyTools.getProxy(rpcUrl);
		var maxWorkers = 4;
		return Promise.promise(true)
			.pipe(function(_) {
				return killAllWorkers();
			})
			//Start with a single worker
			.pipe(function(_) {
				return ScalingCommands.setState({
					MinSize: 1,
					MaxSize: maxWorkers,
					DesiredCapacity: 1
				})
				.thenWait(4000)
				.pipe(function(_) {
					//Check the queue
					traceYellow('After setting max=$maxWorkers');
					return proxy.status()
						.then(function(status) {
							traceYellow(Json.stringify(status, null, '  '));
							return true;
						});
				})
				.pipe(function(_) {
					return ScalingCommands.getAllDockerWorkerIds()
						.then(function(workers) {
							traceYellow('workers=$workers');
							// traceCyan('Ensure a single worker: good, we have a single worker workers=$workers');
							assertEquals(workers.length, 1);
							return true;
						});
				})
				.pipe(function(_) {
					// traceCyan('Make all workers do a health check');
					return WorkerStateRedis.sendCommandToAllWorkers(WorkerUpdateCommand.HealthCheck)
						.then(function(workersString) {
							var workers = Json.parse(workersString);
						})
						.thenWait(500);
				});
			})
			//Now:
			//1. pause the automatic health checks (so we can control it here)
			//2. add a bunch of jobs
			//3. run the lambdas (that should increase the desired amount)
			//4. verify the new number of machines
			//5. run the lambdas again, verify that the workers is back down to minimum
			.pipe(function(_) {
				// traceCyan('Make all workers pause subsequent automatic health checks');
				return WorkerStateRedis.sendCommandToAllWorkers(WorkerUpdateCommand.PauseHealthCheck);
			})
			.pipe(function(_) {
				var numJobs = 20;
				// traceCyan('Create ${numJobs} test jobs');
				return createTestJobs({count:numJobs, duration:30, name:'TimedJob'})
					.thenTrue();
			})
			.thenWait(3000)
				.pipe(function(_) {
					//Check the queue
					traceYellow('After creating many test jobs');
					return proxy.status()
						.then(function(status) {
							traceYellow(Json.stringify(status, null, '  '));
							return true;
						});
				})
			.pipe(function(_) {
				traceCyan('Scale up, this should trigger the creation of a single worker');
				return lambda.scaleUp(AsgType.CPU)
					.thenTrue();
			})

			//Wait until a worker is ready
			.pipe(function(_) {
				return RetryPromise.retryRegular(function() {
					return proxy.status()
						.then(function(status) {
							assertTrue(status.workers.length == 2);
							return true;
						});
				}, 20, 1000);
			})


			.pipe(function(_) {
				// traceCyan('Make all workers do a health check');
				return WorkerStateRedis.sendCommandToAllWorkers(WorkerUpdateCommand.HealthCheck);
			})

			.thenWait(3000)
				.pipe(function(_) {
					//Check the queue
					traceYellow('Scaled up');
					return proxy.status()
						.then(function(status) {
							traceYellow(Json.stringify(status, null, '  '));
							return true;
						});
				})
			.pipe(function(_) {
				// traceCyan('Make all workers do a health check');
				return WorkerStateRedis.sendCommandToAllWorkers(WorkerUpdateCommand.HealthCheck);
			})
			.thenWait(2000)
			.pipe(function(_) {
				// traceCyan('Now check the number of workers, should be 2');
				return ScalingCommands.getAllDockerWorkerIds()
					.then(function(workers) {
						// traceCyan('Final workers after job submission=$workers');
						assertEquals(workers.length, 2);
						return true;
					});
			})

				.pipe(function(_) {
					//Check the queue
					traceYellow('Scaled up');
					return proxy.status()
						.then(function(status) {
							traceYellow(Json.stringify(status, null, '  '));
							return true;
						});
				})

			.pipe(function(_) {
				//Now add a ton of jobs, and run the scale up a bunch of times,
				//we should not go over the max
				var numJobs = 60;
				// traceCyan('Create ${numJobs} test jobs');
				return createTestJobs({count:numJobs, duration:200000, name:'TimedJob'})
					.pipe(function(_) {
						return lambda.scaleUp(AsgType.CPU).thenTrue();
					})
					.thenWait(2000)


						.pipe(function(_) {
							//Check the queue
							traceYellow('After added a ton of long jobs');
							return proxy.status()
								.then(function(status) {
									traceYellow(Json.stringify(status, null, '  '));
									return true;
								});
						})

					.pipe(function(_) {
						// traceCyan('Now check the number of workers, should be $maxWorkers');
						return ScalingCommands.getAllDockerWorkerIds()
							.then(function(workers) {
								// traceCyan('Final workers after multipel jobs and scale ups: job submission=$workers');
								assertEquals(workers.length, 3);
								return true;
							});
					})
					//Scale third time, should be up to the max now
					.pipe(function(_) {
						return lambda.scaleUp(AsgType.CPU).thenTrue();
					})
					.thenWait(2000)
						.pipe(function(_) {
						//Check the queue
						traceYellow('Scaled up after  a bunch of times');
						return proxy.status()
							.then(function(status) {
								traceYellow(Json.stringify(status, null, '  '));
								return true;
							});
						})
					.pipe(function(_) {
						// traceCyan('Now check the number of workers, should be $maxWorkers');
						return ScalingCommands.getAllDockerWorkerIds()
							.then(function(workers) {
								// traceCyan('Final workers after multipel jobs and scale ups: job submission=$workers');
								assertEquals(workers.length, maxWorkers);
								return true;
							});
					})
					//Scale up again, but it should hit the max
					.pipe(function(_) {
						return lambda.scaleUp(AsgType.CPU).thenTrue();
					})
					.thenWait(2000)
					.pipe(function(_) {
						// traceCyan('Now check the number of workers, should be $maxWorkers');
						return ScalingCommands.getAllDockerWorkerIds()
							.then(function(workers) {
								// traceCyan('Final workers after multipel jobs and scale ups: job submission=$workers');
								assertEquals(workers.length, maxWorkers);
								return true;
							});
					})

						.pipe(function(_) {
							//Check the queue
							traceYellow('About to scale down, situation report');
							return proxy.status()
								.then(function(status) {
									traceYellow(Json.stringify(status, null, '  '));
									return true;
								});
						})


					//Scale down, should do nothing
					.pipe(function(_) {
						return lambda.scaleDown(AsgType.CPU).thenTrue();
					})
					.thenWait(2000)

						.pipe(function(_) {
							//Check the queue
							traceYellow('After scaled down with jobs, it should not do anything');
							return proxy.status()
								.then(function(status) {
									traceYellow(Json.stringify(status, null, '  '));
									return true;
								});
						})

					.pipe(function(_) {
						return ScalingCommands.getAllDockerWorkerIds()
							.then(function(workers) {
								assertEquals(workers.length, maxWorkers);
								return true;
							});
					});
			})
			.pipe(function(_) {
				return JobStateTools.cancelAllJobs();
			})
			.thenTrue();
	}

	@timeout(120000)
	public function testServersOnlyWorkersOnly() :Promise<Bool>
	{
		var rpcUrl = '${ScalingServerConfig.DCC}/${Type.enumConstructor(CCCVersion.v1)}';
		var proxy = ccc.compute.client.util.ProxyTools.getProxy(rpcUrl);
		return Promise.promise(true)
			.pipe(function(_) {
				return killAllWorkers();
			})
			.pipe(function(_) {
				return createTestJobs({count:1, duration:0, name:'testServersOnlyWorkersOnly'});
			})
			.thenWait(1000)
			.pipe(function(_) {
				//Check the queue
				return proxy.getQueues()
					.then(function(queues) {
						assertEquals(queues.cpu.waiting, 1);
						return true;
					});
			})
			//Create a worker that CAN process jobs
			.pipe(function(_) {
				return ScalingCommands.createWorker({disableWorker:false, disableServer:true});
			})
			//Wait until a worker is ready
			.pipe(function(_) {
				return RetryPromise.retryRegular(function() {
					return proxy.status()
						.then(function(status) {
							assertTrue(status.workers.length > 0);
							return true;
						});
				}, 20, 1000);
			})
			.pipe(function(_) {
				//Check the queue
				return proxy.getQueues()
					.then(function(queues) {
						assertEquals(queues.cpu.waiting, 0);
						return true;
					});
			})
			.thenTrue();
	}

	public static function createTestJobs(args: TestJobArgs) :Promise<Bool>
	{
		var count = args.count;
		var duration = args.duration;
		var name = args.name;

		function createAndSubmitJob() {
			var jobRequest = ServerTestTools.createTestJobAndExpectedResults(name, duration);
			jobRequest.request.wait = false;
			var f = function() return ccc.compute.client.js.ClientJSTools.postJob(ScalingServerConfig.DCC, jobRequest.request, {});
			return RetryPromise.retryRegular(f, 10, 1000)
				.errorPipe(function(err) {
					traceRed(err);
					return Promise.promise(null);
				})
				.then(function(result) {
					return true;
				});
		}

		var promises = [];
		for (i in 0...count) {
			promises.push(createAndSubmitJob());
		}
		return Promise.whenAll(promises)
			.thenTrue();
	}

	public static function run(injector :Injector) :Promise<CompleteTestResult>
	{
		var runner = new PromiseTestRunner();

		var test = new ScalingTests();
		injector.injectInto(test);
		runner.add(test);

		var exitOnFinish = false;
		var disableTrace = false;
		return runner.run(exitOnFinish, disableTrace)
			.then(function(result) {
				result.tests.iter(function(test) {
					if (test.error != null) {
						traceRed(test.error.replace('\\n', '\n'));
					}
				});
				return result;
			});
	}

	function killAllWorkers()
	{
		return ScalingCommands.killAllWorkersAndJobs(docker)
			.pipe(function(_) {
				return lambda.checks();
			});
	}

	public function new(){}
}