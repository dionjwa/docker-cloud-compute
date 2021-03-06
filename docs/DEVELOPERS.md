# Developing docker-cloud-compute

- [ARCHITECTURE](ARCHITECTURE.md)
- [API](API.md)
- [INSTALL](INSTALL.md)

## Set up:

Run these once:

- Install [docker](https://docs.docker.com/engine/installation/)
- Install [node.js/npm](https://nodejs.org/en/download/)
- `git clone git@github.com:dionjwa/docker-cloud-compute.git` (or your fork)
- `cd docker-cloud-compute`
- `./bin/install`

Then you can start the stack with:

	docker-compose up

If you want the functional tests to be run on code compilation, run the stack with tests enabled:

	TEST=true docker-compose up

Then, if all code is compiled, the test running server will restart the tests.

## Build artifacts

Build artifacts are created in the `./build/` directory:

	./build/server/docker-cloud-compute-server.js

	./build/lambda-autoscaling/index.js
	./build/lambda-autoscaling/package.json
	./build/lambda-autoscaling/node_modules
	./etc/terraform/aws/modules/lambda/lambda.zip


Test artifacts are also there:

	./build/local-scaling-server/docker-cloud-compute-scaling-server.js
	./build/test/docker-cloud-compute-tester.js

## Tests

All tests except scaling tests:

	./bin/test

Scaling only tests:

	./bin/test-scaling

Scaling tests are different because of the length of time taken, and because they remove the current CCC server/worker instance running in docker-compose (and replace it) so logs are no longer visible (a pain when developing).

Scaling tests are NOT run in travis due to unresolved timing issues, likely due to the lack of CPU. Scaling tests need to be run locally on the developers machine. However, it is not often that scaling code is modified, so integrating the two types of tests is not yet a high priority.

## Edit, compile, restart

### Haxe installed locally

You can install [haxe](https://haxe.org/download/) (recommended). Then call:

	haxe etc/hxml/build-all.hxml

This compiles everthing. It's slower than compiling just the part you're working on, so you can run:

	npm run set-build:server

This will replace the file `./build.hxml` so that the default build target (`build.hxml`) is whatever part you're working on. Then:

	haxe build.hxml

A list of haxe plugins for various editors can be found [here](https://haxe.org/documentation/introduction/editors-and-ides.html).


### No Haxe installed locally

Edit code then run:

	./bin/compile

This will compile everything, using haxe locally if you have it installed, otherwise it will use haxe in a docker container (this is a pretty slow way to developer, but it's there if really needed, or if you don't want to install haxe on your host machine).

If you already have the stack running, then you can run (in a separate terminal window):

	docker-compose restart compile

## Compile only specific modules

To compile only the server:

	npm run set-build:server

This modifies the file `build.hxml` in the project root. This file is the default used by haxe IDE/editor plugins (although it can also be changed).

See other options run `npm run | grep set-build`

## Running tests

	./bin/test

These tests run in Travis CI on every pull request.

There are also tests for scaling and worker management. These have problems on Travis CI so are only run locally (due to timing issues, Travis CI machines are quite slow):

	./bin/test-scaling

## Postman tests and example requests

If running locally, go to:

	http://localhost:8080

You will see links to various dashboards. There is a button for Postman API requests that you can run against the service.

## Git tags and docker image publishing

The script below will git tag the version in `package.json`, update local copies of files that hard-code the version (unfortunately) and push the tags to github. This will trigger Travis CI to build and publish the docker images.:

	./bin/version-update

## Environmental variables

[Environment variables that configure the application](../src/haxe/ccc/compute/shared/ServerConfig.hx)

## Developing with a live AWS stack

Example:

	cd etc/terraform/aws/examples/gpu-single

Create a local `terraform.tfvars` file:

	access_key = "XXX"
	secret_key = "XXX"
	region = "us-west-1"
	public_key = "XXX"

Then run the stack:

	terraform apply

Now the stack is running.

Make sure you have your docker keys in `.env`:

	DOCKER_USERNAME=XXX
	DOCKER_PASSWORD=XXX


1. Make code changes
2. Change `package.json#version`
3. ./bin/build-and-push
4. Update etc/terraform/aws/examples/gpu-single/terraform.tfvars with the new version
5. pushd etc/terraform/aws/examples/gpu-single && terraform apply && popd
6. Test.







