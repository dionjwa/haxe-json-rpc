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
				doc: 'arg1doc'
			},
			args2: {
				doc: 'args2doc'
			},
			arg3: {
				doc: 'arg3doc',
				short: 'f'
			}
		}
	})
	public function foo(arg1 :Int, args2 :Array<String>, ?arg3 :String = 'defaultVal', ?arg4 :Bool = false) :Promise<String>
	{
		return null;
	}

	@rpc({
		doc:'foo2 description',
		args:{
			multiArg1: {
				doc: 'Collect the arg',
				short: 'a'
			}
		}
	})
	public function foo2(?multiArg1 :Array<String>) :Promise<String>
	{
		return null;
	}
}