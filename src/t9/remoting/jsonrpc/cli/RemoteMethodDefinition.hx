package t9.remoting.jsonrpc.cli;

import haxe.remoting.JsonRpc;

/**
 * These are the types that can be passed in via the CLI
 * and are checked at runtime.
 */

@:enum
abstract CLIType(String) {
  var Int = 'Int';
  var String = 'String';
  var Unknown = 'Unknown';
}

typedef CLIArgument = {
	var name :String;
	var type :String;
	var optional :Bool;
	@:optional var doc :String;
	@:optional var short :String;
}

typedef RemoteMethodDefinition = {
	var method :String;
	@:optional var doc :String;
	@:optional var alias :String;
	var args :Array<CLIArgument>;
}
