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
		assertEquals('arg1', rpcData[0].args[0].name);
		assertEquals(false, rpcData[0].args[0].optional);

		assertEquals('args2doc', rpcData[0].args[1].doc);
		assertEquals('args2', rpcData[0].args[1].name);
		assertEquals(false, rpcData[0].args[1].optional);

		assertEquals('Collect the arg', rpcData[1].args[0].doc);
		assertEquals('a', rpcData[1].args[0].short);
		assertEquals('multiArg1', rpcData[1].args[0].name);
		assertEquals(true, rpcData[1].args[0].optional);

		assertEquals(null, rpcData[0].args[3].doc);
		assertEquals('arg4', rpcData[0].args[3].name);
		assertEquals(true, rpcData[0].args[3].optional);

		var out :js.node.Buffer = untyped __js__('require("child_process").execSync("haxe test/jsonrpc/cli/mock/main.hxml")');
		var out :js.node.Buffer = untyped __js__('require("child_process").execSync("build/test/cli_test.js aliasToFoo --arg3=testVal --arg4=true 1 arg2_1 arg2_2 arg2_3")');
		var json :RequestDef = Json.parse(out.toString());
		assertEquals(json.method, 'aliasToFoo');
		assertEquals(json.params.arg1, 1);
		switch(json.params.args2) {
			case ['arg2_1', 'arg2_2', 'arg2_3']://Success
			default:assertTrue(false);
		}
		assertEquals(json.params.arg3, 'testVal');
		assertEquals(json.params.arg4, true);

		//Same as above but different variadic args
		var out :js.node.Buffer = untyped __js__('require("child_process").execSync("build/test/cli_test.js aliasToFoo --arg3=testVal --arg4=true 1 arg2_1")');
		var json :RequestDef = Json.parse(out.toString());
		assertEquals(json.method, 'aliasToFoo');
		assertEquals(json.params.arg1, 1);
		switch(json.params.args2) {
			case ['arg2_1']://Success
			default:assertTrue(false);
		}
		assertEquals(json.params.arg3, 'testVal');
		assertEquals(json.params.arg4, true);

		var out :js.node.Buffer = untyped __js__('require("child_process").execSync("build/test/cli_test.js jsonrpc.cli.mock.Foo.foo2 --multiArg1=a --multiArg1=b")');
		var json :RequestDef = Json.parse(out.toString());
		assertEquals(json.method, 'jsonrpc.cli.mock.Foo.foo2');
		assertEquals(json.params.multiArg1.length, 2);
		assertEquals(json.params.multiArg1[0], 'a');
		assertEquals(json.params.multiArg1[1], 'b');
	}
}