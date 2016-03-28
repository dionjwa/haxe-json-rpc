package t9.remoting.jsonrpc;

interface JsonRpcConnection
{
#if python
	public function request(method :String, ?params :Dynamic) :Dynamic;
	public function notify(method :String, ?params :Dynamic) :Bool;
#else
	public function request(method :String, ?params :Dynamic) :promhx.Promise<Dynamic>;
	public function notify(method :String, ?params :Dynamic) :promhx.Promise<Bool>;
#end
}