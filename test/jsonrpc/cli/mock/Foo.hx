package jsonrpc.cli.mock;

import promhx.Promise;

class Foo
{
	/**
	 * Here is some documentation
	 */
	@rpc({
		alias:'aliasToFoo',
		methodDoc:'foo description',
		argumentDocs:{'arg1':'arg1doc','arg2':'arg2doc', 'arg3':'arg3doc'},
		short:{'arg1':'a','arg2':'z', 'arg3':'f'}
	})
	public function foo(arg1 :Int, arg2 :String, ?arg3 :String = 'defaultVal', ?arg4 :Bool = false) :Promise<String>
	{
		return null;
	}

	@rpc({
		methodDoc:'foo2 description'
	})
	public function foo2() :Promise<String>
	{
		return null;
	}
}