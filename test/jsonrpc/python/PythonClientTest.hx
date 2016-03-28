package jsonrpc.python;

import haxe.Json;
import haxe.remoting.JsonRpc;

class BasicsTest extends haxe.unit.TestCase
{
	public function new() {}

	@Test
	public function testStaticClassService ()
	{
		var context = new t9.remoting.jsonrpc.Context();
		jsonrpc.TestService3;
		context.registerService(jsonrpc.TestService3);
	}

	@Test
	public function testStaticClassServiceCalling () :Promise<Bool>
	{

		

		
		var deferred = new Deferred();
		var promise = deferred.promise();

		var context = new t9.remoting.jsonrpc.Context();

		context.registerService(jsonrpc.TestService3);

		var httpServer = Http.createServer(Routes.generatePostRequestHandler(context).bind(_, _, null));

		httpServer.on('error', function(err) {
			promise.reject(err);
		});

		var port = '8082';

		var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttpPost('http://localhost:' + port);

		httpServer.listen(port, function() {
			clientConnection.request(Type.getClassName(jsonrpc.TestService3) + '.foo1', {input:'inputString'})
			.then(function(result :String) {
				httpServer.close(function() {
					if (result == 'inputStringdone') {
						deferred.resolve(true);
					} else {
						promise.reject('Unexpected result=$result != inputStringdone');
					}
				});
			})
			.catchError(function(err) {
				httpServer.close(function() {
					promise.reject(err);
				});
			});
		});

		return promise;
	}
}