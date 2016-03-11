package jsonrpc;

import promhx.Promise;

class TestService3
{
	@rpc
	public static function foo1(input:String) :Promise<String>
	{
		return Promise.promise(input + "done");
	}
}