package ccc.compute.test.tests.cwl;

import ccc.compute.client.js.ClientJSTools;

import js.npm.shortid.ShortId;

class TestCWLApi extends ServerAPITestBase
{
	public static var TEST_BASE = 'tests';
	@inject public var _rpc :RpcRoutes;

	@timeout(240000)
	public function testWorkflowDynamicInput() :Promise<Bool>
	{
		var git = 'https://github.com/dionjwa/cwltool';
		var sha = 'dfbf4330f9c137f2261b9edc06d323ad91fd8345';
		var cwl = 'tests/ccc_docker_workflow/run_workflow.cwl';

		var inputDeclarationFileName = 'input.yml';
		var input = '/inputs/$inputDeclarationFileName';
		var inputFileName = 'inputTest';
		var testValue = 'testValue${ShortId.generate()}';
		var inputs :DynamicAccess<String> = {};
		inputs.set(inputDeclarationFileName, '
infile:
  class: File
  path: /inputs/$inputFileName
');
		inputs.set(inputFileName, testValue);

		return _rpc.workflowRun(git, sha, cwl, input, inputs)
			.pipe(function(jobResult) {
				return _rpc.getJobResult(jobResult.jobId);
			})
			.pipe(function(jobResult :JobResultAbstract) {
				assertTrue(jobResult.outputs.length == 1);
				assertEquals(jobResult.outputs[0], 'outfile2');
				var outputUrl1 = jobResult.getOutputUrl(jobResult.outputs[0]);
				return RequestPromises.get(outputUrl1)
					.then(function(out) {
						out = out != null ? out.trim() : out;
						assertEquals(out, testValue);
						return true;
					});
			});
	}

	@timeout(240000)
	public function testWorkflowNoExtraInput() :Promise<Bool>
	{
		var git = 'https://github.com/dionjwa/cwltool';
		var sha = 'dfbf4330f9c137f2261b9edc06d323ad91fd8345';
		var cwl = 'tests/ccc_docker_workflow/run_workflow.cwl';
		var input = 'tests/ccc_docker_workflow/input.yml';

		return _rpc.workflowRun(git, sha, cwl, input)
			.pipe(function(jobResult) {
				return _rpc.getJobResult(jobResult.jobId);
			})
			.pipe(function(jobResult :JobResultAbstract) {
				assertTrue(jobResult.outputs.length == 1);
				assertEquals(jobResult.outputs[0], 'outfile2');
				var outputUrl1 = jobResult.getOutputUrl(jobResult.outputs[0]);
				return RequestPromises.get(outputUrl1)
					.then(function(out) {
						out = out != null ? out.trim() : out;
						assertEquals(out, 'foobar');
						return true;
					});
			});
	}

	public function new()
	{
		super();
	}
}