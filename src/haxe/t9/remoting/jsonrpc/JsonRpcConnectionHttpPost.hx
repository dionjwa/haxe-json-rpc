package t9.remoting.jsonrpc;

#if (nodejs && !macro)
	import js.node.Buffer;
	import js.node.Url;
	import js.node.Http;
#end

import haxe.remoting.JsonRpc;
import haxe.Json;

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

	public function addHeaders(headers :Dynamic)
	{
		_headers = headers;
		return this;
	}

	public function debug()
	{
		_debug = true;
		return this;
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
				trace('response=${Json.stringify(response)}');
				if (response.error != null) {
					//Rethrow
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
#elseif js

		var execute = function(resolve, reject) {
			var postData = Json.stringify(request);
			if (_debug) {
				trace('POST DATA: ${postData}');
			}
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

			if (_headers != null) {
				for (f in Reflect.fields(_headers)) {
					Reflect.setField(postOptions.headers, f, Reflect.field(_headers, f));
				}
			}
			if (_debug) {
				trace('POST OPTIONS: ${Json.stringify(postOptions)}');
			}
			// Set up the request
			var postReq = js.node.Http.request(postOptions, function(res) {
				var responseData :Buffer = new Buffer(0);
				res.on('data', function (chunk :Buffer) {
					responseData = Buffer.concat([responseData, chunk]);
				});
				res.on('end', function () {
					var responseString = responseData.toString('utf8');
					if (_debug) {
						trace('POST RESPONSE: statusCode=[${res.statusCode}] data=[${responseString}] request=[$postData]');
					}
					var responseObj :ResponseDef = try {Json.parse(responseString);} catch(ignored :Dynamic) {null;};
					var isResponseObj = responseObj != null && responseObj.jsonrpc == JsonRpcConstants.JSONRPC_VERSION_2;
					if (res.statusCode >= 400) {
						responseObj = isResponseObj ? responseObj :
							{
								id :request.id,
								error: {code:res.statusCode, message:'${responseData.toString('utf8')}'},
								jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
							};
						resolve(responseObj);
					} else {
						if (request.id != null) {
							try {
								resolve(responseObj);
							} catch(err :Dynamic) {
								var responseDef :ResponseDef = {
									id :request.id,
									error: {code:-32603, message:'Invalid JSON was received by the client.', data:{response:Std.string(responseData), request:request}},
									jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
								};
								resolve(responseDef);
							}
						} else {
							resolve(null);
						}
					}
				});
				res.on('error', reject);
			});

			postReq.on('socket', function (socket) {
				socket.setTimeout(1000 * 60 * 60); // 1 hour
				socket.on('timeout', function() {
					postReq.abort();
				});
			});

			postReq.on('error', function(err) {
				var responseDef :ResponseDef = {
					id :request.id,
					error: {code:-32603, message:'POST request error', data:Json.stringify(err)},
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
				};
				resolve(responseDef);
			});
			// post the data
			postReq.write(postData);
			postReq.end();
		}

		#if (promise == "js.npm.bluebird.Bluebird")
			return new Promise<ResponseDef>(execute);
		#else
			var promise = new promhx.deferred.DeferredPromise();
			execute(promise.resolve, promise.boundPromise.reject);
			return promise.boundPromise;
		#end

#else
		var promise = new promhx.deferred.DeferredPromise();
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
				var responseDef :ResponseDef = {
					id :request.id,
					error: {code:-32603, httpStatusCode:status, message:'Invalid JSON was received by the client.', data:Std.string(response)},
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
				};
				promise.resolve(responseDef);
			}
		};
		h.onError = function(err) {
			var responseDef :ResponseDef = {
				id :request.id,
				error: {code:-32603, message:'Error on request', data:Std.string(err), httpStatusCode:500},
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
			};
			promise.resolve(responseDef);
		};
		h.request(true);
		return promise.boundPromise;
#end
	}

	var _url :String;
	var _idCount :Int = 0;
	var _headers :Dynamic;
	var _debug :Bool = false;
}
