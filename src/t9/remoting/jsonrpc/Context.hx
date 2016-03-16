package t9.remoting.jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.rtti.Meta;

import promhx.Promise;
import promhx.Deferred;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

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
    macro public function registerService(self :Expr, service :Expr) :Expr
    {
    	var serviceType = haxe.macro.Context.typeof(service);
    	var className;
    	switch(serviceType) {
    		case TInst(t, params):
    			var classType = t.get();
    			className = classType.pack != null && classType.pack.length >= 1 ? classType.pack.join('.') + '.' + classType.name : classType.name;
    		case TType(t, params):
    			switch(t.get().type) {
    				case TInst(t2, params):
		    			var classType = t2.get();
	    				className = classType.pack != null && classType.pack.length >= 1 ? classType.pack.join('.') + '.' + classType.name : classType.name;
	    			case TAnonymous(a):
	    				className = t9.remoting.jsonrpc.Macros.getClassNameFromClassExpr(service);
	    			default:
    					haxe.macro.Context.error('Not handled serviceType=TType(${t.get().type}) service=${service}', haxe.macro.Context.currentPos());
    			}
    		case TAnonymous(a):
				haxe.macro.Context.error('Not handled serviceType=${serviceType} service=${service}', haxe.macro.Context.currentPos());
    		default:
    			haxe.macro.Context.error('Not handled serviceType=$serviceType  service=${service}', haxe.macro.Context.currentPos());
    	}
    	var methodDefinitions = t9.remoting.jsonrpc.Macros.getMethodDefinitionsInternal([className]);
    	return macro $self._registerServiceInternal(${service}, $v{methodDefinitions});
    }


    public function _registerServiceInternal(service :Dynamic, methodDefinitions: Array<RemoteMethodDefinition>)
	{
		var isServiceStaticClass = Type.getClass(service) == null;
		var type = isServiceStaticClass ? service : Type.getClass(service);
		for (methodDef in methodDefinitions) {
			if (isServiceStaticClass && !methodDef.isStatic) {
				continue;
			}
			var serviceObjectToCall = methodDef.isStatic ? type : service;
			bindMethod(serviceObjectToCall, methodDef);
		}
	}

	function bindMethod(service :Dynamic, methodDef :RemoteMethodDefinition)
	{
		var fieldName = methodDef.field;
		var method = Reflect.field(service, fieldName);
		var call = function(request :RequestDef) {
			var params;
			if (request.params == null) {
				params = [];
			} else if (untyped __js__('request.params.constructor === Array')) {
				params = request.params;
			} else {
				params = [];
				//The method definitions are ordered
				for (argDef in methodDef.args) {
					if (Reflect.hasField(request.params, argDef.name)) {
						params.push(Reflect.field(request.params, argDef.name));
					} else {
						params.push(null);
					}
				}
			}
			var promise :Promise<Dynamic> = Reflect.callMethod(service, method, params);
			return promise;
		}
		var methodName = methodDef.method;
		if (_methods.exists(methodName)) {
			throw 'Context.bindMethod already has a binding for $methodName';
		}
		_methods.set(methodName, call);

		if (methodDef.alias != null) {
			if (_methods.exists(methodDef.alias)) {
				throw 'Context.bindMethod already has a binding for ${methodDef.alias}';
			}
			_methods.set(methodDef.alias, call);
		}
	}

	public function isRegistered(method :String) :Bool
	{
		return _methods.exists(method);
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
				trace('err=${err}');
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