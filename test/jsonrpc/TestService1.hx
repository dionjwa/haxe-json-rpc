package jsonrpc;

import promhx.Promise;

class TestService1
{
	var x :Int;

	public function new(){}

	@rpc
	public function foo1(args :{input:String}) :Promise<String>
	{
		return Promise.promise(args.input + "done");
	}

	@rpc({alias:'fooalias'})
	public function foo2(args :{input:String}) :Promise<String>
	{
		return Promise.promise(args.input + "done2");
	}

	//@rpc
	public function foo3(args :{input:String}) :String
	{
		return 'testNotPromise';
	}

	public function notRemoteMethod(args :{input:String}) :Promise<String>
	{
		return Promise.promise(args.input + "done2");
	}
}