package jsonrpc;

import promhx.Promise;

class TestService1
{
	var x :Int;

	public function new(){}

	@rpc
	public function foo1(input1 :String, ?input2 :String) :Promise<String>
	{
		return Promise.promise(input1 + "done");
	}

	@rpc({alias:'fooalias'})
	public function foo2(input:String) :Promise<String>
	{
		return Promise.promise(input + "done2");
	}

	public function foo3(args :{input:String}) :String
	{
		return 'testNotPromise';
	}

	public function notRemoteMethod(input:String) :Promise<String>
	{
		return Promise.promise(input + "done2");
	}
}