package haxe.remoting;

/**
 * http://www.jsonrpc.org/specification
 */

typedef JsonRpcMessage = {
	@:optional //Not strictly optional but if you own the client and server, it's not necessary.
	var jsonrpc :String;
}

typedef RequestDefTyped<T> = { > JsonRpcMessage,
	var method :String;
	@:optional var id :Dynamic;
	@:optional var params :T;
}

typedef RequestDef = RequestDefTyped<Dynamic>;

@:enum
abstract JsonRpcErrorCode(Int) {
  var ParseError = -32700;
  var InvalidRequest = -32600;
  var MethodNotFound = -32601;
  var InvalidParams = -32602;
  var InternalError = -32603;
  //-32000 to -32099 Server error Reserved for implementation-defined server-errors.
}


typedef ResponseError = {
	var code :Int;
	var message :String;
	@:optional var data :Dynamic;
}

typedef ResponseDef = { > JsonRpcMessage,
	var id :Dynamic;
	@:optional var result :Dynamic;
	@:optional var error :ResponseError;
}

typedef ResponseDefSuccess<T> = { > JsonRpcMessage,
	var id :Dynamic;
	var result :T;
}

typedef ResponseDefError = { > JsonRpcMessage,
	var id :Dynamic;
	var error :ResponseError;
}

class JsonRpcConstants
{
	inline public static var JSONRPC_VERSION_2 = '2.0';
	inline public static var MULTIPART_JSONRPC_KEY = 'jsonrpc';
}