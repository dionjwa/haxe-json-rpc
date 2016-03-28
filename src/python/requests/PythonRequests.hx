package batcher.services.scheduling.client.externs.python;

import python.KwArgs;

typedef PythonRequestPostArgs = {
	@:optional var data :Dynamic;
	@:optional var headers :Dynamic<String>;
	@:optional var files:Dynamic<Dynamic>;
}

@:pythonImport("requests")
extern class PythonRequests {
	static function post(url :String, ?kwargs:KwArgs<Dynamic>) :PythonResponse;
	static function get(url :String, ?kwargs:KwArgs<Dynamic>) :PythonResponse;
}

extern class PythonResponse {
	var text :String;
	var url :String;
}