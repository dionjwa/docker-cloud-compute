package ccc.compute.client;

import haxe.remoting.JsonRpc;

import ccc.compute.JobTools;
import ccc.compute.ServiceBatchCompute;
import ccc.compute.client.cli.CliTools.*;

import promhx.Promise;
import promhx.deferred.DeferredPromise;

using StringTools;
using ccc.compute.ComputeTools;

typedef JobDataBlob = {>JobResult,
	var url :String;
}

/**
 * Exposes the API of the server is a more convenient way,
 * and provides some utility methods.
 */
@:expose('ClientCompute')
class ClientCompute
{
	@:expose
	public static function postJob(host :Host, job :BasicBatchProcessRequest, ?forms :Dynamic) :Promise<{jobId:JobId}>
	{
		var promise = new DeferredPromise();
		var jsonRpcRequest :RequestDef = {
			id: JsonRpcConstants.JSONRPC_NULL_ID,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
			method: Constants.RPC_METHOD_JOB_SUBMIT,
			params: job
		}

		var formData = {
			jsonrpc: Json.stringify(jsonRpcRequest)
		};
		if (forms != null) {
			for (f in Reflect.fields(forms)) {
				Reflect.setField(formData, f, Reflect.field(forms, f));
			}
		}
		js.npm.request.Request.post({url:host.rpcUrl(), formData:formData},
			function(err :js.Error, httpResponse :js.npm.request.Request.HttpResponse, body:js.npm.request.Request.Body) {
				if (err != null) {
					Log.error(err);
					promise.boundPromise.reject(err);
					return;
				}
				if (httpResponse.statusCode == 200) {
					try {
						// var result :JobResult = Json.parse(body);
						var result :ResponseDefSuccess<{jobId:JobId}> = Json.parse(body);
						promise.resolve(result.result);
					} catch (err :Dynamic) {
						promise.boundPromise.reject(err);
					}
				} else {
					promise.boundPromise.reject('non-200 response body=$body');
				}
			});
		return promise.boundPromise;
	}

	public static function getJobResultData(host :Host, jobId :JobId) :Promise<JobResult>
	{
		if (jobId == null) {
			Log.warn('Null jobId passed');
			return Promise.promise(null);
		} else {
			var clientProxy = getProxy(host.rpcUrl());
			return clientProxy.doJobCommand(JobCLICommand.Result, [jobId])
				.then(function(out :TypedDynamicObject<JobId,Dynamic>) {
					var result :JobResult = Reflect.field(out, jobId);
					JobTools.prependJobResultsUrls(result, host + '/');
					return result;
				});
		}
	}

	public static function getJobResult(host :Host, jobId :JobId) :Promise<JobResult>
	{
		return ClientTools.getJobResult(host, jobId, getJobResultData.bind(host, jobId));
	}

	public static function getJobData(host :Host, jobId :JobId) :Promise<JobDescriptionComplete>
	{
		var clientProxy = getProxy(host.rpcUrl());

		return clientProxy.doJobCommand(JobCLICommand.Result, [jobId])
			.then(function(out :TypedDynamicObject<JobId,Dynamic>) {
				var result :JobDescriptionComplete = Reflect.field(out, jobId);
				return result;
			});

		// var resultJson :JobDataBlob = null;
		// var url = '$baseUrl/${JobTools.RESULTS_JSON_FILE}';
		// // trace('curl $url');
		// return promhx.RequestPromises.get(url)
		// 	.pipe(function(result) {
		// 		if (result == null || result.trim() == '') {
		// 			throw 'No ${JobTools.RESULTS_JSON_FILE}';
		// 		}
		// 		resultJson = Json.parse(result);
		// 		resultJson.url = '$baseUrl/outputs/';
		// 		return Promise.promise(true)
		// 			.pipe(function(_) {
		// 				return promhx.RequestPromises.get('$baseUrl/stderr')
		// 					.then(function(result) {
		// 						resultJson.stderr = result;
		// 						return true;
		// 					})
		// 					.errorPipe(function(err) {
		// 						//No stderr, swallow error and keep going
		// 						return Promise.promise(true);
		// 					});
		// 			})
		// 			.pipe(function(_) {
		// 				return promhx.RequestPromises.get('$baseUrl/stdout')
		// 					.then(function(result) {
		// 						resultJson.stdout = result;
		// 						return true;
		// 					})
		// 					.errorPipe(function(err) {
		// 						//No stdout, swallow error and keep going
		// 						return Promise.promise(true);
		// 					});
		// 			})
		// 			.then(function(_) {
		// 				// trace(Json.stringify(resultJson, null, '\t'));
		// 				return resultJson;
		// 			});
		// 	});
	}

	public static function pollJobResult(host :Host, jobId :JobId, ?maxAttempts :Int = 10, intervalMs :Int = 200) :Promise<JobDescriptionComplete>
	{
		return promhx.RetryPromise.pollRegular(function() {
			return getJobData(host, jobId);
		}, maxAttempts, intervalMs, null, true);
	}

	static function main() {}
}