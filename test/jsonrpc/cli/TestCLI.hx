package jsonrpc.cli;

import haxe.Json;
import haxe.unit.async.PromiseTest;
import haxe.remoting.JsonRpc;

import promhx.Promise;
import promhx.Deferred;

class TestCLI extends PromiseTest
{
	public function new() {}

	public function testCLI()
	{
		untyped __js__('require("child_process").execSync("haxe test/jsonrpc/cli/mock/main.hxml")');
		var out = untyped __js__('require("child_process").execSync("build/cli_test.js aliasToFoo 1 arg2 --arg3 testVal --arg4")');
		var json :RequestDef = Json.parse(out);
		assertEquals(json.method, 'jsonrpc.cli.mock.Foo.foo');
		assertEquals(json.params.arg1, 1);
		assertEquals(json.params.arg2, 'arg2');
		assertEquals(json.params.arg3, 'testVal');
		assertEquals(json.params.arg4, true);

		var out = untyped __js__('require("child_process").execSync("build/cli_test.js jsonrpc.cli.mock.Foo.foo 1 arg2 --arg3 testVal --arg4")');
		var json :RequestDef = Json.parse(out);
		assertEquals(json.method, 'jsonrpc.cli.mock.Foo.foo');
		assertEquals(json.params.arg1, 1);
		assertEquals(json.params.arg2, 'arg2');
		assertEquals(json.params.arg3, 'testVal');
		assertEquals(json.params.arg4, true);
	}
}