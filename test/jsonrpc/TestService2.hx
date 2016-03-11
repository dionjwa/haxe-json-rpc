package jsonrpc;

import promhx.Promise;

class TestService2
{
	var x :Int;

	public function new(){}

	@rpc
	public function foo21(input:String) :Promise<String>
	{
		return Promise.promise(input + "done");
	}

	@rpc({alias:'fooalias2'})
	public function foo22(args :{input:String}) :Promise<String>
	{
		return Promise.promise(args.input + "done2");
	}

	//@rpc
	public function foo3(args :{input:String}) :String
	{
		return 'testNotPromise';
	}

	public function notRemoteMethod(input:String) :Promise<String>
	{
		return Promise.promise(input + "done2");
	}
}