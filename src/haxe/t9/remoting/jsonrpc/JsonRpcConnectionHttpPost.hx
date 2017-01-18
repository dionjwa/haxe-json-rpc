package t9.remoting.jsonrpc;

#if (nodejs && !macro)
	import js.node.Buffer;
	import js.node.Url;
	import js.node.Http;
#end

import haxe.remoting.JsonRpc;
import haxe.Json;

#if !js
	import promhx.Deferred;
#end

class JsonRpcConnectionHttpPost
	implements JsonRpcConnection
{
	public static function urlConnect(url :String)
	{
		return new JsonRpcConnectionHttpPost(url);
	}

	public function new(url)
	{
		_url = url;
	}

#if python
	public function request(method :String, ?params :Dynamic) :Dynamic
#else
	public function request(method :String, ?params :Dynamic) :Promise<Dynamic>
#end
	{
		var requestObj :RequestDef = {
			id: (++_idCount) + '',
			method: method,
			params: params,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
#if python
		return callInternal(requestObj).result;
#else
		return callInternal(requestObj)
			.then(function(response: ResponseDef) {
				if (response.error != null) {
					//Add the request to the error object for better error tracking
					// Reflect.setField(response.error, 'request', requestObj);
					// throw Json.stringify(response.error, null, '  ');
					throw response.error;
				}
				return response.result;
			});
#end
	}

#if python
	public function notify(method :String, ?params :Dynamic) :Bool
#else
	public function notify(method :String, ?params :Dynamic) :Promise<Bool>
#end
	{
		var request :RequestDef = {
			method: method,
			params: params,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
#if python
		callInternal(request);
		return true;
#else
		return callInternal(request)
			.then(function(_) {
				return true;
			});
#end
	}

#if python
	function callInternal(request :RequestDef) :ResponseDef
#else
	function callInternal(request :RequestDef) :Promise<ResponseDef>
#end
	{
#if python
		var response :ResponseDef = {
			id: request.id,
			result: '',
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
		return response;
#else
	#if nodejs
		return new Promise<ResponseDef>(function(resolve, reject) {
			var postData = Json.stringify(request);
			// An object of options to indicate where to post to
			var urlObj = js.node.Url.parse(_url);
			var postOptions :HttpRequestOptions = cast {
				hostname: urlObj.hostname,
				port: urlObj.port,
				path: urlObj.path,
				method: 'POST',
				headers: {
					'Content-Type': 'application/json-rpc',
					'Content-Length': postData.length
				}
			};
			// Set up the request
			var postReq = js.node.Http.request(postOptions, function(res) {
				var responseData :Buffer = new Buffer(0);
				res.on('data', function (chunk :Buffer) {
					responseData = Buffer.concat([responseData, chunk]);
				});
				res.on('end', function () {
					if (request.id != null) {
						try {
							var jsonRes = Json.parse(responseData.toString('utf8'));
							resolve(jsonRes);
						} catch(err :Dynamic) {
							resolve({
								id :request.id,
								error: {code:-32603, message:'Invalid JSON was received by the client.', data:Std.string(responseData)},
								jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
							});
						}
					} else {
						resolve(null);
					}
				});
			});

			postReq.on('error', function(err) {
				reject(err);
			});

			// post the data
			postReq.write(postData);
			postReq.end();
		});
	#else
		var promise = new DeferredPromise();
		var h = new haxe.Http(_url);
		h.setHeader("content-type","application/json-rpc");

		h.setPostData(Json.stringify(request));

		var status :Int = -1;

		h.onStatus = function(s) {
			status = s;
		};

		h.onData = function(response :String) {
			try {
				var ret = Json.parse(response);
				promise.resolve(ret);
			} catch( err : Dynamic ) {
				promise.resolve({
					id :request.id,
					error: {code:-32603, httpStatusCode:status, message:'Invalid JSON was received by the client.', data:Std.string(response)},
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
				});
			}
		};
		h.onError = function(err) {
			promise.resolve({
				id :request.id,
				error: {code:-32603, message:'Error on request', data:Std.string(err)},
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
			});
		};
		h.request(true);
		return promise.boundPromise;
	#end
#end
	}

	var _url :String;
	var _idCount :Int = 0;
}
