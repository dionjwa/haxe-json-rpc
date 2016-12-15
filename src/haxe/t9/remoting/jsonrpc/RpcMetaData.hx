package t9.remoting.jsonrpc;

typedef RpcMetaData = {
	@:optional var methodDoc :String;
	@:optional var alias :String;
	@:optional var express :String;
	@:optional var argumentDocs :Dynamic<String>;
	@:optional var short :Dynamic<String>;
}