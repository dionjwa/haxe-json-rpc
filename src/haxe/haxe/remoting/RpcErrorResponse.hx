package haxe.remoting;

/**
 * If you throw this object, then you can control the http status code,
 * (if HTTP+RPC) and the exact message returned to clients. This helps
 * to return non-fatal errors and legit non-2** status codes.
 */
class RpcErrorResponse
{
	public var HttpStatusCode :Int;
	public var Message :String;

	public function new(code :Int, message :String)
	{
		this.HttpStatusCode = code;
		this.Message = message;
	}
}