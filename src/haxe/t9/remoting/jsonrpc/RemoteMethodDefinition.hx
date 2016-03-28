package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;

/**
 * These are the types that can be passed in via the CLI
 * and are checked at runtime.
 */

@:enum
abstract RemoteMethodArgumentType(String) {
  var Int = 'Int';
  var String = 'String';
  var Unknown = 'Unknown';
}

typedef RemoteMethodArgument = {
	var name :String;
	var type :String;
	var optional :Bool;
	@:optional var doc :String;
	@:optional var short :String;
}

typedef RemoteMethodDefinition = {
	var field :String;
	var method :String;
	@:optional var doc :String;
	@:optional var alias :String;
	var args :Array<RemoteMethodArgument>;
	var isStatic :Bool;
}
