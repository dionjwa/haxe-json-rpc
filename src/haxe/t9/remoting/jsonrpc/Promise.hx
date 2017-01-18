package t9.remoting.jsonrpc;

#if nodejs
	typedef Promise<T>=js.npm.bluebird.Bluebird<T,Dynamic>;
#else
	typedef Promise<T>=promhx.Promise<T>;
#end
