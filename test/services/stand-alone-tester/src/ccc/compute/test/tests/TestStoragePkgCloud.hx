package ccc.compute.test.tests;

import promhx.RetryPromise;
import promhx.RequestPromises;

import util.streams.StreamTools;

class TestStoragePkgCloud extends TestStorageBase
{
	@timeout(1000)
	public function testPathsS3() :Promise<Bool>
	{
		return doPathParsing(new ccc.storage.ServiceStoragePkgCloud().setConfig(
			{
				type: ccc.storage.StorageSourceType.PkgCloud,
				container: 'somecontainer',
				rootPath: null,
				httpAccessUrl: 'http://foobar',
				credentials: {
					provider: "amazon",
					keyId: "AKIA",
					key: "F5yk",
					region: "us-west-1"
				}
			}));
	}

	@timeout(10000)
	override public function testFileExists() :Promise<Bool>
	{
		return super.testFileExists();
	}

	@timeout(10000)
	override public function testGettingFileThatDoesNotExist() :Promise<Bool>
	{
		return super.testGettingFileThatDoesNotExist();
	}

	// AWS S3 allows path-like object names
	// @timeout(100)
	// function TODO_CHECK_THIS_testPathConversion() :Promise<Bool>
	// {
	// 	var storageService = new ccc.storage.ServiceStorageS3().setConfig(
	// 		{
	// 			type: ccc.storage.StorageSourceType.Cloud,
	// 			container: 'somecontainer',
	// 			rootPath: null,
	// 			httpAccessUrl: 'http://foobar',
	// 			credentials: {
	// 				provider: "amazon",
	// 				keyId: "AKIA",
	// 				key: "F5yk",
	// 				region: "us-west-1"
	// 			}
	// 		});

	// 	var testPath0 :String = "molecule0/dataset0/file0.csv.gz";
	// 	var convertedTestPath0 :String = "foo/bar/good/molecule0/dataset0/file0.csv.gz";

	// 	return Promise.promise(true)
	// 		.then(function (_) {
	// 			Assert.that(storageService.getRootPath() == "/");
	// 			storageService.appendToRootPath("foo");
	// 			Assert.that(storageService.getRootPath() == "/foo/");
	// 			storageService.appendToRootPath("bar/");
	// 			Assert.that(storageService.getRootPath() == "/foo/bar/");
	// 			storageService.appendToRootPath("//good//");
	// 			Assert.that(storageService.getRootPath() == "/foo/bar/good/");

	// 			var storageServiceS3 :ServiceStorageS3 = cast storageService;
	// 			Assert.that(storageServiceS3.convertPath(testPath0) == convertedTestPath0);
	// 			return true;
	// 		});
	// }

	@timeout(100)
	public function XtestCloudPathParsingExternalUrl() :Promise<Bool>
	{
		var config = {
			type: ccc.storage.StorageSourceType.PkgCloud,
			container: 'somecontainer',
			rootPath: null,
			httpAccessUrl: 'http://foobar',
			credentials: {
				provider: "amazon",
				keyId: "AKIA",
				key: "F5yk",
				region: "us-west-1"
			}
		};
		var s = new ccc.storage.ServiceStoragePkgCloud().setConfig(config);

		var rootPath = 'rootPathTest';
		var storage :ccc.storage.ServiceStorageBase = cast s.clone();

		storage.setRootPath(rootPath);

		var filePath = 'some/file/path';

		assertEquals(storage.getPath(filePath), '${storage.getRootPath()}${filePath}');
		assertEquals(storage.getExternalUrl(filePath), '${config.httpAccessUrl}/${rootPath}/${filePath}');

		return Promise.promise(true);
	}

	@timeout(30000)
	public function XtestStorageTestPkgCloud() :Promise<Bool>
	{
		Assert.notNull(_storage);
		return doStorageTest(_storage);
	}

	@timeout(30000)
	public function XtestPkgCloudExternalUrl() :Promise<Bool>
	{
		Assert.notNull(_storage);
		return Promise.promise(true)
			.pipe(function(_) {
				var testFileName = 'testExternalUrlFile${Math.floor(Math.random() * 1000000)}';
				var testFileContent = 'testFileContent${Math.floor(Math.random() * 1000000)}';
				return _storage.writeFile(testFileName, StreamTools.stringToStream(testFileContent))
					.pipe(function(_) {
						var outputUrl = _storage.getExternalUrl(testFileName);
						assertNotEquals(outputUrl, testFileName);
						assertTrue(outputUrl.startsWith('http'));
						return RetryPromise.retryRegular(
							function() {
								return RequestPromises.get(outputUrl);
							}, 10, 200);
					})
					.then(function(out) {
						out = out != null ? out.trim() : out;
						assertEquals(out, testFileContent);
						return true;
					});
			});
	}

	@timeout(30000)
	public function testPkgCloudCopyEmptyFile() :Promise<Bool>
	{
		Assert.notNull(_storage);
		return Promise.promise(true)
			.pipe(function(_) {
				var testFileName = 'testExternalUrlFile${Math.floor(Math.random() * 1000000)}';
				var testFileContent = 'testFileContent${Math.floor(Math.random() * 1000000)}';
				return _storage.writeFile(testFileName, StreamTools.stringToStream(testFileContent))
					.pipe(function(_) {
						var outputUrl = _storage.getExternalUrl(testFileName);
						assertNotEquals(outputUrl, testFileName);
						assertTrue(outputUrl.startsWith('http'));
						return RetryPromise.retryRegular(
							function() {
								return RequestPromises.get(outputUrl);
							}, 10, 200);
					})
					.then(function(out) {
						out = out != null ? out.trim() : out;
						assertEquals(out, testFileContent);
						return true;
					});
			});
	}

	// @timeout(30000)
	// public function testS3ListDir() :Promise<Bool>
	// {
	// 	return _storage.listDir()
	// 		.pipe(function(files) {
	// 			Assert.notNull(files);
	// 			return Promise.promise(true);
	// 		});
	// }

	// @timeout(30000)
	// public function XtestS3WriteFile() :Promise<Bool>
	// {
	// 	var storageService = _storage;
	// 	var rand = Std.int(Math.random() * 1000000);
	// 	var testFileContent = 'This is an example: 久有归天愿. $rand';
	// 	var testFilePath = 'testfile-autogen-$rand.txt';

	// 	return Promise.promise(true)
	// 		.pipe(function (_) {
	// 			var outputStream = StreamTools.stringToStream(testFileContent);
	// 			return storageService.writeFile(testFilePath, outputStream);
	// 		})
	// 		.pipe(function (_) {
	// 			return storageService.listDir(testFilePath);
	// 		})
	// 		.then(function(files) {
	// 			Assert.that(files.exists(function(f) return f == testFilePath));
	// 			return true;
	// 		})
	// 		.pipe(function (_) {
	// 			return storageService.deleteFile(testFilePath);
	// 		})
	// 		.pipe(function (_) {
	// 			return storageService.listDir(testFilePath);
	// 		})
	// 		.then(function(files) {
	// 			Assert.that(! files.exists(function(f) return f == testFilePath));
	// 			return true;
	// 		});
	// }

	// // @timeout(30000)
	// // public function testStorage() :Promise<Bool>
	// // {
	// // 	return this.doServiceStorageTest(storageService);
	// // }

	// function XtestStorageDefinitionFromServiceConfiguration() :Promise<Bool>
	// {
	// 	var configFilePath = 'server/servers/etc/serverconfig.amazon.s3.template.yml';
	// 	var config = InitConfigTools.getConfig(configFilePath);
	// 	var storageDefinition = config.server.storage;//ServiceStorageS3.getS3ConfigFromServiceConfiguration(serviceConfiguration);
	// 	return Promise.promise(true)
	// 		.then(function (_) {
	// 			Assert.notNull(storageDefinition);
	// 			return true;
	// 		});
	// }

	// @timeout(30000)
	// public function XtestS3CopyFile() :Promise<Bool>
	// {
	// 	var testFileContent = 'This is an example: 久有归天愿.';
	// 	var testFilePath = "testfile-autogen.txt";

	// 	var copyFilePath = "testfile-autogen-copy.txt";

	// 	var baseStorage :ServiceStorageBase = cast _storage;

	// 	return Promise.promise(true)
	// 		.pipe(function (_) {
	// 			return baseStorage.listDir()
	// 				.then(function(files) {
	// 					trace('files=${files}');
	// 					return true;
	// 				});
	// 		})
	// 		.pipe(function (_) {
	// 			var outputStream = StreamTools.stringToStream(testFileContent);
	// 			return baseStorage.writeFile(testFilePath, outputStream);
	// 		})
	// 		.pipe(function (_) {
	// 			return baseStorage.listDir();
	// 		})
	// 		.then(function(files) {
	// 			Assert.that(files.exists(function(f) return f == testFilePath));
	// 			return true;
	// 		})
	// 		.pipe(function (_) {
	// 			return baseStorage.copyFile(testFilePath, copyFilePath);
	// 		})
	// 		.pipe(function (_) {
	// 			return baseStorage.listDir(copyFilePath);
	// 		})
	// 		.then(function(files) {
	// 			Assert.that(files.exists(function(f) return f == copyFilePath));
	// 			return true;
	// 		})
	// 		.pipe(function (_) {
	// 			return baseStorage.deleteFile(testFilePath);
	// 		})
	// 		.pipe(function (_) {
	// 			return baseStorage.deleteFile(copyFilePath);
	// 		})
	// 		.pipe(function (_) {
	// 			return baseStorage.listDir("testfile-autogen");
	// 		})
	// 		.then(function (files) {
	// 			Assert.that(files.length == 0);
	// 			return true;
	// 		});
	// }

	// @timeout(30000)
	// public function XtestS3HttpAccess() :Promise<Bool>
	// {
	// 	var testFileContent = 'This is an example for HTTP access: 久有归天愿.';
	// 	var testFilePath = "testfile-http-access.txt";

	// 	var s3Storage :ServiceStorageS3 = cast _storage;
	// 	return Promise.promise(true)
	// 		.pipe(function (_) {
	// 			var outputStream = StreamTools.stringToStream(testFileContent);
	// 			return s3Storage.writeFile(testFilePath, outputStream);
	// 		})
	// 		.pipe(function (_) {
	// 			var httpAccessUrl = s3Storage.getExternalUrl(testFilePath);
	// 			return RequestPromises.get(httpAccessUrl);
	// 		})
	// 		.then(function (content :String) {
	// 			Assert.notNull(content);
	// 			Assert.that(content == testFileContent);
	// 			return true;
	// 		})
	// 		.pipe(function (_){
	// 			return s3Storage.deleteFile(testFilePath);
	// 		})
	// 		.pipe(function (_) {
	// 			return s3Storage.listDir(testFilePath);
	// 		})
	// 		.then(function(files) {
	// 			Assert.that(! files.exists(function(f) return f == testFilePath));
	// 			return true;
	// 		});
	// }

	public function new() { super(); }
}