package t9.remoting.jsonrpc;

#if (promise == "js.npm.bluebird.Bluebird")
	typedef Promise<T>=js.npm.bluebird.Bluebird<T,Dynamic>;
#elseif (promise == "js.Promise")
	typedef Promise<T>=js.Promise<T>;
#else
	typedef Promise<T>=promhx.Promise<T>;
#end
