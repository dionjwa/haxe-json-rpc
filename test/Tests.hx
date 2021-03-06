package ;

class Tests
{
	public static function main () :Void
	{
		new haxe.unit.async.PromiseTestRunner()

			.add(new jsonrpc.BasicsTest())
			.add(new jsonrpc.RpcHttpTest())
			.add(new jsonrpc.RpcHttpGetTest())
			.add(new jsonrpc.RpcProxyTest())
			.add(new jsonrpc.RpcWebSocketTest())
			.add(new jsonrpc.TestExpressRoutes())
			.add(new jsonrpc.cli.TestCLI())

			.run();

#if (nodejs && !travis)
		try {
			untyped __js__("if (require.resolve('source-map-support')) {require('source-map-support').install(); console.log('source-map-support installed');}");
		} catch (e :Dynamic) {}
#end
	}
}
