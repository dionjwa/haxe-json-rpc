package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;

import promhx.Promise;

interface JsonRpcConnection
{
	public function request(method :String, ?params :Dynamic) :Promise<Dynamic>;
	public function notify(method :String, ?params :Dynamic) :Promise<Bool>;
}