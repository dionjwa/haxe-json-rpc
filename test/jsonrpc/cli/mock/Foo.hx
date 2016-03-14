package jsonrpc.cli.mock;

import promhx.Promise;

class Foo
{
	/**
	 * Here is some documentation
	 */
	@rpc({
		alias:'aliasToFoo',
		doc:'foo description',
		args:{
			arg1: {
				doc: 'arg1doc',
				short: 'a'
			},
			arg2: {
				doc: 'arg2doc',
				short: 'z'
			},
			arg3: {
				doc: 'arg3doc',
				short: 'f'
			}
		}
	})
	public function foo(arg1 :Int, arg2 :String, ?arg3 :String = 'defaultVal', ?arg4 :Bool = false) :Promise<String>
	{
		return null;
	}

	@rpc({
		doc:'foo2 description'
	})
	public function foo2() :Promise<String>
	{
		return null;
	}
}