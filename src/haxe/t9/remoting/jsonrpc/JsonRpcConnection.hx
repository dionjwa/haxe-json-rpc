package t9.remoting.jsonrpc;

interface JsonRpcConnection
{
#if python
	public function request(method :String, ?params :Dynamic) :Dynamic;
	public function notify(method :String, ?params :Dynamic) :Bool;
#else
	/**
	 * The return is the actual final function return, not an RpcResponse
	 */
	public function request(method :String, ?params :Dynamic) :Promise<Dynamic>;
	public function notify(method :String, ?params :Dynamic) :Promise<Bool>;
#end
}