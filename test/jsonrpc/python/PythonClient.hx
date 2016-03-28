package jsonrpc.python;

import haxe.Json;
import haxe.remoting.JsonRpc;

// import jsonrpc.TestService1;
// import jsonrpc.TestService2;

class PythonClient
{

	static function main()
	{
		var port = jsonrpc.TestServer.PORT;
		var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttpPost('http://localhost:' + port);

		// var result = clientConnection.request(Type.getClassName(TestService1) + '.foo1', {input1:'inputString', input2:'inputString2'});
		// trace(result);
	}
}