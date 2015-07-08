package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;

import promhx.Promise;

interface JsonRpcConnection
{
	public function call(method :String, ?params :Dynamic) :Promise<Dynamic>;
}