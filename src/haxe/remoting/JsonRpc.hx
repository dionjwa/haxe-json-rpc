package haxe.remoting;

/**
 * http://www.jsonrpc.org/specification
 */

typedef JsonRpcMessage = {
	@:optional //Not strictly optional but if you own the client and server, it's not necessary.
	var jsonrpc :String;
}

typedef RequestDef = { > JsonRpcMessage,
	var method :String;
	@:optional var id :Dynamic;
	@:optional var params :Dynamic;
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