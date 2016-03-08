package t9.remoting.jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.rtti.Meta;

import promhx.Promise;
import promhx.Deferred;

using Lambda;

class Context
{
	@:allow(js.npm.JsonRpcExpressTools)
	var _methods :Map<String, RequestDef->Promise<Dynamic>>;

	public function new ()
	{
		_methods = new Map();
	}

	public function dispose()
	{
		_methods = null;
	}

	/**
	 * Get all methods annotated with 'rpc' and bind them to the service.
	 */
	public function registerService(service :Dynamic)
	{
		var type = Type.getClass(service) == null ? service : Type.getClass(service);
		var metafields = Type.getClass(service) == null ? Meta.getStatics(type) : Meta.getFields(type);

		for (metafield in Reflect.fields(metafields)) {
			var fieldData = Reflect.field(metafields, metafield);

			if (Reflect.hasField(fieldData, 'rpc')) {
				var methodName = Type.getClassName(type) + "." + metafield;
				bindMethod(service, metafield, methodName);
				//Also add the argument in case we want to use different names
				var meta :RpcMetaData = Reflect.field(fieldData, 'rpc') != null ? Reflect.field(fieldData, 'rpc')[0] : null;
				if (meta != null && meta.alias != null) {
					bindMethod(service, metafield, meta.alias);
				}
			}
		}
	}

	function bindMethod(service :Dynamic, fieldName :String, methodName :String)
	{
		var method = Reflect.field(service, fieldName);
		_methods.set(methodName,
			function(request :RequestDef) {
				if (request.params == null) {
					request.params = [];
				}
				var promise :Promise<Dynamic> = Reflect.callMethod(service, method, [request.params]);
				return promise;
			});
	}

	public function handleRpcRequest(request :RequestDef) :Promise<ResponseDef>
	{
		if (_methods.exists(request.method)) {
			var call = _methods.get(request.method);
			try {
				return call(request)
					.then(function(result :Dynamic) {
						var responseSuccess :ResponseDef = {
							id :request.id,
							result: result,
							jsonrpc: "2.0"
						};
						return responseSuccess;
					})
					.errorPipe(function(err) {
						var responseError :ResponseDef = {
							id :request.id,
							error: {code:-32603, message:'Internal RPC error', data:err},
							jsonrpc: "2.0"
						};
						return Promise.promise(responseError);
					})
					.then(function(response :ResponseDef) {
						return response;
					});
			} catch(err :Dynamic) {
				var responseError :ResponseDef = {
					id :request.id,
					error: {code:-32603, message:'Method threw exception="${request.method}"', data:err},
					jsonrpc: "2.0"
				};
				return Promise.promise(responseError);
			}
		} else {
			var responseError :ResponseDef = {
				id :request.id,
				error: {code:-32601, message:'The method="${request.method}" does not exist / is not available. Available methods=[' + [for (s in _methods.keys()) s].join(',') + ']'},
				jsonrpc: "2.0"
			};
			return Promise.promise(responseError);
		}
	}
}