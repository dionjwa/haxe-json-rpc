package jsonrpc;

import promhx.Promise;

class TestService3
{
	@rpc
	public static function foo1(args :{input:String}) :Promise<String>
	{
		return Promise.promise(args.input + "done");
	}
}