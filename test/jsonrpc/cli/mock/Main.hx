package jsonrpc.cli.mock;

import t9.remoting.jsonrpc.cli.RemoteMethodDefinition;
import t9.remoting.jsonrpc.cli.CommanderTools;

class Main
{
	static function main()
	{
		var rpcData :Array<RemoteMethodDefinition>= t9.remoting.jsonrpc.cli.Macros.getMethodDefinitions(jsonrpc.cli.mock.Foo);
		var requestRPC = CommanderTools.parseCliArgs(rpcData);
		trace(haxe.Json.stringify(requestRPC));
	}
}

