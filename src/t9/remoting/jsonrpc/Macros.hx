package t9.remoting.jsonrpc;

import Type in StdType;

import promhx.Promise;
import promhx.Deferred;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.MacroStringTools;
import haxe.macro.Printer;
#end

using StringTools;

/**
  * Macros for creating remoting JsonRpc proxy classes from the remoting class or
  * remoting interfaces.
  */
class Macros
{
	/**
	  * Takes a server remoting class and the connection variable,
	  * and returns an instance of the newly created proxy class.
	  */
	macro
	public static function buildRpcClient(classExpr: Expr, connection: Expr) :Expr
	{
		var pos = Context.currentPos();

		var className = getClassNameFromClassExpr(classExpr);
		if (className == null || className == "") {
			throw className + " not found. Maybe specify the entire class identifier?";
		}
		var proxyClassName = (className.lastIndexOf('.') > -1 ? className.substr(className.lastIndexOf('.') + 1) : className ) + "Proxy" + (Std.int(Math.random() * 100000));

		var rpcType = Context.getType(className);
		var newFields = [];
		switch(rpcType) {
			case TInst(t, params):
				var fields = t.get().fields.get();
				for (field in fields) {
					if (field.meta.has('rpc')) {
						var promiseType;
						var functionArgs;
						switch(TypeTools.follow(field.type)) {
							//args: Array<{ name : String, opt : Bool, t : Type }>
							case TFun(args, ret):
								//This is the type of the Promise return
								if (ret.getParameters()[0] + '' != 'promhx.Promise') {
									throw '@rpc method must return a promhx.Promise object';
								}
								promiseType = ret.getParameters()[1][0];
								functionArgs = args;
							default: throw '"@rpc" metadata on a variable ${field.name}, only allowed on methods.';
						}

						if (functionArgs.length > 1) {
							throw 'Current we only support passing in the entire params object';
						}
						switch(field.kind) {
							case FMethod(k):
							default: throw '"@rpc" metadata on a variable ${field.name}, only allowed on methods.';
						}
						newFields.push(
							{
								name: field.name,
								doc: null,
								meta: [],
								access: [APublic],
								kind: FFun({
									args: functionArgs.map(
											function(arg) {//{ name : String, opt : Bool, t : Type }
												var funcArg :FunctionArg = {
													name: arg.name,
													type: TypeTools.toComplexType(arg.t)
												};
												return funcArg;
											}),
									ret: ComplexType.TPath(
										{
											name:'Promise',
											pack:['promhx'],
											params:
												[
													TPType(TypeTools.toComplexType(promiseType))
												]
										}),
									expr : functionArgs.length > 0 ?
												macro {
													if (_addToAllParams.length > 0) {
														for(pair in _addToAllParams) {
															Reflect.setField($i{functionArgs[0].name}, pair.key, pair.val);
														}
													}
													return cast _conn.call($v{className} + '.' + $v{field.name}, $i{functionArgs[0].name});
												}
											:
												macro {
													var args;
													if (_addToAllParams.length > 0) {
														args = {};
														for(pair in _addToAllParams) {
															Reflect.setField(args, pair.key, pair.val);
														}
													}
													return cast _conn.call($v{className} + '.' + $v{field.name}, args);
												}
								}),
								pos: pos
							}
						);
					}
				}
			default:
		}

		//If you're building the proxy, you don't want the remote logic compiled in
#if !include_server_logic
		Compiler.exclude(className);
#end
		var c = macro class $proxyClassName
		{
			var _conn :t9.remoting.jsonrpc.JsonRpcConnection;
			var _addToAllParams :Array<{key:String, val :Dynamic}>;
			public function new(conn :t9.remoting.jsonrpc.JsonRpcConnection)
			{
				_conn = conn;
				_addToAllParams = [];
			}

			public function addToAllParams(key :String, val :Dynamic)
			{
				for (pair in _addToAllParams) {
					if (pair.key == key) {
						pair.val = val;
						return;
					}
				}
				_addToAllParams.push({key:key, val:val});
			}
		}
		c.fields = c.fields.concat(newFields);

		haxe.macro.Context.defineType(c);
		var type = TypeTools.toComplexType(Context.getType(proxyClassName));
		var typePath :TypePath = {name:proxyClassName, pack:[], params:null, sub:null};
		return macro new $typePath ($connection);
	}

#if macro
	public static function getClassNameFromClassExpr (classNameExpr :Expr) :String
	{
		var drillIntoEField = null;
		var className = "";
		drillIntoEField = function (e :Expr) :String {
			switch(e.expr) {
				case EField(e2, field):
					return drillIntoEField(e2) + "." + field;
				case EConst(c):
					switch(c) {
						case CIdent(s):
							return s;
						case CString(s):
							return s;
						default:Context.warning(StdType.enumConstructor(c) + " not handled", Context.currentPos());
							return "";
					}
				default: Context.warning(StdType.enumConstructor(e.expr) + " not handled", Context.currentPos());
					return "";
			}
		}
		switch(classNameExpr.expr) {
			case EField(e1, field):
				className = field;
				switch(e1.expr) {
					case EField(_, _):
						className = drillIntoEField(e1) + "." + className;
					case EConst(c):
						switch(c) {
							case CIdent(s):
								className = s + "." + className;
							case CString(s):
								className = s + "." + className;
							default:Context.warning(StdType.enumConstructor(c) + " not handled", Context.currentPos());
						}
					default: Context.warning(StdType.enumConstructor(e1.expr) + " not handled", Context.currentPos());
				}
			case EConst(c):
				switch(c) {
					case CIdent(s):
						className = s;
					case CString(s):
						className = s;
					default:Context.warning(StdType.enumConstructor(c) + " not handled", Context.currentPos());
				}
			default: Context.warning(StdType.enumConstructor(classNameExpr.expr) + " not handled", Context.currentPos());
		}

		return className;
	}
#end
}
