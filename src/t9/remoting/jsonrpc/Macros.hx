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

import t9.remoting.jsonrpc.RemoteMethodDefinition;

using StringTools;
using Lambda;

typedef MacroContext=haxe.macro.Context;

/**
  * Macros for creating remoting JsonRpc proxy classes from the remoting class or
  * remoting interfaces.
  */
class Macros
{
	static var metaKey = 'rpc';
	/**
	 * This takes in a number of classes (not instances) and extracts the
	 * remoting methods in JSON method definitions that can then be used
	 * by other tools.
	 * @param  e<Expr> Classes to extract RPC method data.
	 * @return         Array<RemoteMethodDefinition>
	 */
	macro public static function getMethodDefinitions(classes:Array<ExprOf<Class<Dynamic>>>) :Expr //Array<RemoteMethodDefinition>
	{
		var pos = MacroContext.currentPos();
		var classNames = [];
		for (classExpression in classes) {
			var typeof = MacroContext.typeof(classExpression);
			var className = getClassNameFromClassExpr(classExpression);
			if (className == null || className == "") {
				MacroContext.error(className + " not found. Maybe specify the entire class identifier?", pos);
			}
			classNames.push(className);
		}
		var remoteDefinitions = getMethodDefinitionsInternal(classNames);
		return macro $v {remoteDefinitions};
	}
#if macro
	public static function getMethodDefinitionsInternal(classes:Array<String>) :Array<RemoteMethodDefinition>
	{
		var pos = haxe.macro.Context.currentPos();

		var remoteDefinitions :Array<RemoteMethodDefinition> = [];

		for (className in classes) {
			var rpcType = haxe.macro.Context.getType(className);
			var newFields = [];
			var fields = [];
			var statics = new Map();
			switch(rpcType) {
				case TInst(t, params):
					fields = fields.concat(t.get().fields.get());
					var staticFields = t.get().statics.get();
					for (f in staticFields) {
						statics.set(f, true);
					}
					fields = fields.concat(staticFields);
				default:
			}

			for (field in fields) {
				if (field.meta.has(metaKey)) {
					var definition :RemoteMethodDefinition = {'method':'$className.${field.name}', field:field.name, args:[], alias:null, isStatic:statics.exists(field)};
					remoteDefinitions.push(definition);
					var functionArgs;
					switch(TypeTools.follow(field.type)) {
						case TFun(args, ret):
							for (arg in args) {
								var argumentTypeString = TypeTools.toString(arg.t);
								if (argumentTypeString.startsWith('Null')) {
									argumentTypeString = argumentTypeString.substring(5, argumentTypeString.length - 1);
								}
								var typeEnum :RemoteMethodArgumentType = cast argumentTypeString;
								var methodArgument :RemoteMethodArgument = {name :arg.name, optional:arg.opt, type:argumentTypeString, doc:null, short:null};
								definition.args.push(methodArgument);
							}

							var metaRpc = field.meta.extract(metaKey).find(function(x) return x.name == metaKey);
							if (metaRpc.params != null) {
								for (param in metaRpc.params) {
									switch(param.expr) {
										case EObjectDecl(expr):
											for (metaObjectField in expr) {
												if (metaObjectField.field == 'alias') {
													switch(metaObjectField.expr.expr) {
														case EConst(CString(s)):definition.alias = s;
														default: Context.error('$className.${field.name}: rpc metadata ' + "'alias' field must be a String.", pos);
													}
												} else if (metaObjectField.field == 'argumentDocs') {
													switch(metaObjectField.expr.expr) {
														case EObjectDecl(objectDeclaration):
															for (objectItemExpr in objectDeclaration) {
																switch(objectItemExpr.expr.expr) {
																	case EConst(CString(s)):
																		var docKey = objectItemExpr.field.substr("@$__hx__".length);
																		var arg :RemoteMethodArgument = definition.args.find(function(v) return v.name == docKey);
																		if (arg == null) {
																			Context.error('$className.${field.name}: rpc metadata ' + "'docs' values: there is no matching method argument '" + docKey + "'", pos);
																		}
																		arg.doc = s;
																	default: Context.error('$className.${field.name}: rpc metadata ' + "'docs' values must be Strings", pos);
																}
															}
														default: Context.error('$className.${field.name}: rpc metadata ' + "'docs' field must be an Object.", pos);
													}
												} else if (metaObjectField.field == 'args') {
													switch(metaObjectField.expr.expr) {
														case EObjectDecl(argsObjDecl):
															for (objectItemExpr in argsObjDecl) {
																//objectItemExpr contains all the fields for the argument options
																var argumentKey = objectItemExpr.field;
																if (argumentKey.startsWith("@$__hx__")) {
																	argumentKey = argumentKey.replace("@$__hx__", "");
																}
																var arg :RemoteMethodArgument = definition.args.find(function(v) return v.name == argumentKey);
																if (arg == null) {
																	Context.error('$className.${field.name}: @rpc{args:{${argumentKey}:{}}} "${argumentKey}" is not a method argument.', pos);
																}
																switch(objectItemExpr.expr.expr) {
																	case EObjectDecl(argsObjItemDecl):
																		for (argItem in argsObjItemDecl) {
																			var argItemKey = argItem.field;
																			if (argItemKey.startsWith("@$__hx__")) {
																				argItemKey = argItemKey.replace("@$__hx__", "");
																			}
																			var argItemValue = switch(argItem.expr.expr) {
																				case EConst(CString(s)): s;
																				default: Context.error('$className.${field.name}: @rpc{"args":{"$argumentKey":{"$argItemKey":<val>}}} <val> must be a string.', pos);
																			}
																			if (argItemKey == 'doc') {
																				arg.doc = argItemValue;
																			} else if (argItemKey == 'short') {
																				if (argItemValue.length > 1) {
																					Context.error('$className.${field.name}: @rpc{"args":{"$argumentKey":{"short":"$argItemValue"}}} "$argItemValue" is too long. "short" values must be a single character.', pos);
																				}
																				arg.short = argItemValue;
																			} else {
																				Context.error('$className.${field.name}: @rpc{"args":{"$argumentKey":{"$argItemKey":"$argItemValue"}}} "$argItemKey" is not a recogized key: [doc,short]', pos);
																			}
																		}
																	default:
																}
															}
														default: Context.error('$className.${field.name}: rpc metadata ' + "'docs' field must be an Object.", pos);
													}
												} else if (metaObjectField.field == 'doc') {
													switch(metaObjectField.expr.expr) {
														case EConst(CString(s)):
															definition.doc = s;
														default: Context.error('$className.${field.name}: rpc metadata ' + "'doc' field must be an String.", pos);
													}
												} else if (metaObjectField.field == 'short') {
													switch(metaObjectField.expr.expr) {
														case EObjectDecl(objectDeclaration):
															for (objectItemExpr in objectDeclaration) {
																switch(objectItemExpr.expr.expr) {
																	case EConst(CString(s)):
																		var argKey = objectItemExpr.field.substr("@$__hx__".length);
																		var arg :RemoteMethodArgument = definition.args.find(function(v) return v.name == argKey);
																		if (arg == null) {
																			Context.error('$className.${field.name}: rpc metadata ' + "'short' values: there is no matching method argument '" + argKey + "'", pos);
																		}
																		if (s.length != 1) {
																			Context.error('$className.${field.name}: rpc metadata ' + "'short' values must be a string of length=1, '" + s + "'.length=" + s.length, pos);
																		}
																		arg.short = s;
																	default: Context.error('$className.${field.name}: rpc metadata ' + "'docs' values must be Strings", pos);
																}
															}
														default: Context.error('$className.${field.name}: rpc metadata ' + "'docs' field must be an Object.", pos);
													}
												} else {
													Context.error('$className.${field.name}: Unrecognized field (${metaObjectField.field}) in rpc metadata. Allows fields=[alias, docs, methodDoc, short]', pos);
												}
											}
										default:
											Context.error("The rpc metadata must be an object formatted e.g. {'alias':'alias1', 'docs':{'argumentName1':'argumentDocString1', 'argumentName2':'argumentDocString2'}}. All fields are optional", pos);
									}
								}
							}
							functionArgs = args;
						default: throw '"@$metaKey" metadata on a variable ${field.name}, only allowed on methods.';
					}

					switch(field.kind) {
						case FMethod(k):
						default: throw '"@$metaKey" metadata on a variable ${field.name}, only allowed on methods.';
					}
				}
			}
		}
		return remoteDefinitions;
	}
#end

	/**
	  * Takes a server remoting class and the connection variable,
	  * and returns an instance of the newly created proxy class.
	  */
	macro
	public static function buildRpcClient(classExpr: Expr) :Expr
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
													type: TypeTools.toComplexType(arg.t),
													opt: arg.opt
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
									expr :
										Context.parse(
											"{\n" +
												"var args = {};\n" +
												functionArgs.map(function(functionArg) return "Reflect.setField(args, '" + functionArg.name + "', " + functionArg.name + ");").join('\n') +
												"\nreturn cast _conn.request('" + className + '.' + field.name +"', args);\n" +
											"}"
											, pos)
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

			public function new()
			{
				_addToAllParams = [];
			}

			public function setConnection(conn :t9.remoting.jsonrpc.JsonRpcConnection)
			{
				_conn = conn;
				return this;
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
		return macro new $typePath ();
	}

#if macro
	public static function getClassNameFromClassExpr (classNameExpr :Expr) :String
	{
		// trace('classNameExpr=${classNameExpr}');
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
