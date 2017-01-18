package t9.remoting.jsonrpc;

import js.node.Url;
import js.node.Http;
import js.node.Querystring;
import js.node.stream.Readable;

import haxe.remoting.JsonRpc;
import haxe.Json;

#if !js
	import promhx.deferred.DeferredPromise;
#end



using StringTools;

class JsonRpcConnectionHttpGet
	implements JsonRpcConnection
{
	public static function urlConnect(url :String)
	{
		return new JsonRpcConnectionHttpGet(url);
	}

	public function new(url)
	{
		_url = url;
	}

	public function request(method :String, ?params :Dynamic) :Promise<Dynamic>
	{
		var request :RequestDef = {
			id: (++_idCount) + '',
			method: method,
			params: params,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
		return callInternal(request)
			.then(function(response: ResponseDef) {
				if (response.error != null) {
					throw response.error;
				}
				return response.result;
			});
	}

	public function notify(method :String, ?params :Dynamic) :Promise<Bool>
	{
		var request :RequestDef = {
			method: method,
			params: params,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
		return callInternal(request)
			.then(function(_) {
				return true;
			});
	}

	function callInternal(request :RequestDef) :Promise<ResponseDef>
	{
#if nodejs
		return new Promise(function(resolve :ResponseDef->Void, reject :Dynamic->Void) {
			// An object of options to indicate where to post to
			var urlObj = js.node.Url.parse(_url);
			var requestOptions :HttpRequestOptions = {
				hostname: urlObj.hostname,
				port: urlObj.port != null ? Std.parseInt(urlObj.port) : 80,
				path: urlObj.path + (urlObj.path.endsWith('/') ? '' : '/') + request.method + (request.params != null ? '?' + Querystring.stringify(request.params) : ''),
				method: 'GET',
				protocol: urlObj.protocol
			};
			var isReturned = false;
			// Set up the request
			var getReq = js.node.Http.request(requestOptions, function(res) {
				res.setEncoding('utf8');
				var responseData = '';
				res.on(ReadableEvent.Data, function (chunk) {
					responseData += chunk;
				});
				res.on(ReadableEvent.Error, function (err) {
					reject(err);
					isReturned = true;
				});
				res.on(ReadableEvent.End, function () {
					if (isReturned) {
						return;
					}
					if (request.id != null) {
						try {
							var jsonRes = Json.parse(responseData);
							resolve(jsonRes);
							isReturned = true;
						} catch(err :Dynamic) {
							resolve({
								id :request.id,
								error: {code:-32603, message:'Invalid JSON was received by the client.', data:responseData},
								jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
							});
							isReturned = true;
						}
					} else {
						resolve(null);
					}
				});
			});

			getReq.on(ReadableEvent.Error, function(err) {
				if (!isReturned) {
					reject(err);
					isReturned = true;
				}
			});

			getReq.end();
		});
#else
		var promise = new DeferredPromise<ResponseDef>();
		var h = new haxe.Http(_url);
		h.setHeader("content-type","application/json-rpc");

		h.setPostData(Json.stringify(request));

		h.onData = function(response :String) {
			try {
				var ret = Json.parse(response);
				deferred.resolve(ret);
			} catch( err : Dynamic ) {
				deferred.resolve({
					id :request.id,
					error: {code:-32603, message:'Invalid JSON was received by the client.', data:response},
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
				});
			}
		};
		h.onError = function(err) {
			deferred.resolve({
				id :request.id,
				error: {code:-32603, message:'Error on request', data:err},
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
			});
		};
		h.request(true);
		return promise.boundPromise;
#end
	}

	var _url :String;
	var _idCount :Int = 0;
}
