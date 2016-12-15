package jsonrpc;

import promhx.Promise;

class TestService3
{
	@rpc
	public static function foo1(input:String) :Promise<String>
	{
		return Promise.promise(input + "done");
	}

	@rpc({
		alias:'express-route-test',
		express: '/foo/bar/:value1/:value2'
	})
	public static function expressRouteTest(value1:String, value2:Int) :Promise<String>
	{
		return Promise.promise(value1 + "::" + value2);
	}
}