package jsonrpc.cli;

import haxe.Json;
import haxe.unit.async.PromiseTest;
import haxe.remoting.JsonRpc;
import t9.remoting.jsonrpc.RemoteMethodDefinition;

import promhx.Promise;
import promhx.Deferred;

class TestCLI extends PromiseTest
{
	public function new() {}

	public function testCLI()
	{
		var rpcData :Array<RemoteMethodDefinition>= t9.remoting.jsonrpc.Macros.getMethodDefinitions(jsonrpc.cli.mock.Foo);
		assertEquals('aliasToFoo', rpcData[0].alias);
		assertEquals('jsonrpc.cli.mock.Foo.foo', rpcData[0].method);
		assertEquals(false, rpcData[0].isStatic);

		assertEquals('arg1doc', rpcData[0].args[0].doc);
		assertEquals('a', rpcData[0].args[0].short);
		assertEquals('arg1', rpcData[0].args[0].name);
		assertEquals(false, rpcData[0].args[0].optional);

		assertEquals('arg2doc', rpcData[0].args[1].doc);
		assertEquals('z', rpcData[0].args[1].short);
		assertEquals('arg2', rpcData[0].args[1].name);
		assertEquals(false, rpcData[0].args[1].optional);

		assertEquals(null, rpcData[0].args[3].doc);
		assertEquals('arg4', rpcData[0].args[3].name);
		assertEquals(true, rpcData[0].args[3].optional);

		untyped __js__('require("child_process").execSync("haxe test/jsonrpc/cli/mock/main.hxml")');
		var out = untyped __js__('require("child_process").execSync("build/cli_test.js aliasToFoo 1 arg2 --arg3 testVal --arg4")');
		var json :RequestDef = Json.parse(out);
		assertEquals(json.method, 'jsonrpc.cli.mock.Foo.foo');
		assertEquals(json.params.arg1, 1);
		assertEquals(json.params.arg2, 'arg2');
		assertEquals(json.params.arg3, 'testVal');
		assertEquals(json.params.arg4, true);

		var out = untyped __js__('require("child_process").execSync("build/cli_test.js jsonrpc.cli.mock.Foo.foo2")');
		var json :RequestDef = Json.parse(out);
		assertEquals(json.method, 'jsonrpc.cli.mock.Foo.foo2');
	}
}