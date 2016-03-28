/**
 * This is a dummy server for testing any client calls. The server is
 * node.js but the client can be any language.
 */
package jsonrpc;

#if nodejs
	import haxe.Json;
	import haxe.remoting.JsonRpc;

	import js.Node;
	import js.node.Http;

	import promhx.Promise;
	import promhx.Deferred;

	import t9.js.jsonrpc.Routes;
#end

class TestServer
{
	public static var PORT = '8082';

#if nodejs
	static function main()
	{
		var context = new t9.remoting.jsonrpc.Context();

		var service1 = new TestService1();
		var service2 = new TestService2();

		context.registerService(service1);
		context.registerService(service2);

		var httpServer = Http.createServer(Routes.generatePostRequestHandler(context).bind(_, _, null));

		httpServer.on('error', function(err) {
			Log.error(err);
		});

		httpServer.listen(PORT, function() {
			Log.info('Server listening on 0.0.0.0:$PORT');
		});
	}
#end
}