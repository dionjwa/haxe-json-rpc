package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;
import haxe.Json;

import promhx.Promise;
import promhx.Deferred;

class JsonRpcConnectionHttp
	implements JsonRpcConnection
{
	public static function urlConnect(url :String)
	{
		return new JsonRpcConnectionHttp(url);
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
			jsonrpc: "2.0"
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
			jsonrpc: '2.0'
		};
		return callInternal(request)
			.then(function(_) {
				return true;
			});
	}

	function callInternal(request :RequestDef) :Promise<ResponseDef>
	{
		var deferred = new Deferred<ResponseDef>();
		var promise = deferred.promise();
#if nodejs
		var postData = Json.stringify(request);
		// An object of options to indicate where to post to
		var urlObj = js.node.Url.parse(_url);
		var postOptions :js.node.Url.UrlObj = cast {
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
			res.setEncoding('utf8');
			var responseData = '';
			res.on('data', function (chunk) {
				responseData += chunk;
			});
			res.on('end', function () {
				if (request.id != null) {
					try {
						var jsonRes = Json.parse(responseData);
						deferred.resolve(jsonRes);
					} catch(err :Dynamic) {
						deferred.resolve({
							id :request.id,
							error: {code:-32603, message:'Invalid JSON was received by the client.', data:responseData},
							jsonrpc: "2.0"
						});
					}
				} else {
					deferred.resolve(null);
				}
			});
		});

		postReq.on('error', function(err) {
			promise.reject(err);
		});

		// post the data
		postReq.write(postData);
		postReq.end();
#else
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
					jsonrpc: "2.0"
				});
			}
		};
		h.onError = function(err) {
			deferred.resolve({
				id :request.id,
				error: {code:-32603, message:'Error on request', data:err},
				jsonrpc: "2.0"
			});
		};
		h.request(true);
#end
		return promise;
	}

	var _url :String;
	var _idCount :Int = 0;
}
