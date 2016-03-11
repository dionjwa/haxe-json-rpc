package jsonrpc.cli.mock;

import t9.remoting.jsonrpc.RemoteMethodDefinition;
import t9.remoting.jsonrpc.cli.CommanderTools;

class Main
{
	static function main()
	{
		var rpcData :Array<RemoteMethodDefinition>= t9.remoting.jsonrpc.Macros.getMethodDefinitions(jsonrpc.cli.mock.Foo);
		var requestRPC = CommanderTools.parseCliArgs(rpcData);
		var out = haxe.Json.stringify(requestRPC);
		untyped __js__('console.log(out)');
	}
}

