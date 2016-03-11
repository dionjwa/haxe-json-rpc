package t9.remoting.jsonrpc.cli;

import haxe.remoting.JsonRpc;
import t9.remoting.jsonrpc.RemoteMethodDefinition;

import haxe.macro.Expr;
import haxe.macro.TypeTools;

using StringTools;
using Lambda;

typedef MacroContext=haxe.macro.Context;

class Macros
{
	/**
	 * This takes in a number of classes (not instances) and extracts the
	 * remoting methods in JSON method definitions that can then be used
	 * by other tools.
	 * @param  e<Expr> Classes to extract RPC method data.
	 * @return         Array<RemoteMethodDefinition>
	 */
	// macro public static function getMethodDefinitions(classes:Array<ExprOf<Class<Dynamic>>>) :Expr //Array<RemoteMethodDefinition>
	// {
	// 	// trace('classes=${classes}');
	// 	var metaKey = 'rpc';
	// 	var pos = MacroContext.currentPos();

	// 	var remoteDefinitions :Array<RemoteMethodDefinition> = [];

	// 	// for (classExpression in classes) {
	// 	for (className in classes) {

	// 		// var typeof = haxe.macro.Context.typeof(classExpression);
	// 		// trace('typeof=${typeof}');
	// 		// var className = t9.remoting.jsonrpc.Macros.getClassNameFromClassExpr(classExpression);
	// 		// if (className == null || className == "") {
	// 		// 	throw className + " not found. Maybe specify the entire class identifier?";
	// 		// }

	// 		var rpcType = MacroContext.getType(className);
	// 		var newFields = [];
	// 		var fields = [];
	// 		var statics = new Map();
	// 		switch(rpcType) {
	// 			case TInst(t, params):
	// 				fields = fields.concat(t.get().fields.get());
	// 				var staticFields = t.get().statics.get();
	// 				for (f in staticFields) {
	// 					statics.set(f, true);
	// 				}
	// 				fields = fields.concat(staticFields);
	// 			default:
	// 		}

	// 		for (field in fields) {
	// 			if (field.meta.has(metaKey)) {
	// 				var definition :RemoteMethodDefinition = {'method':'$className.${field.name}', field:field.name, args:[], alias:null, isStatic:statics.exists(field)};
	// 				remoteDefinitions.push(definition);
	// 				var functionArgs;
	// 				switch(TypeTools.follow(field.type)) {
	// 					case TFun(args, ret):
	// 						for (arg in args) {
	// 							var argumentTypeString = TypeTools.toString(arg.t);
	// 							if (argumentTypeString.startsWith('Null')) {
	// 								argumentTypeString = argumentTypeString.substring(5, argumentTypeString.length - 1);
	// 							}
	// 							var typeEnum :RemoteMethodArgumentType = cast argumentTypeString;
	// 							var methodArgument :RemoteMethodArgument = {name :arg.name, optional:arg.opt, type:argumentTypeString, doc:null};//
	// 							definition.args.push(methodArgument);
	// 						}

	// 						var metaRpc = field.meta.extract(metaKey).find(function(x) return x.name == metaKey);
	// 						if (metaRpc.params != null) {
	// 							for (param in metaRpc.params) {
	// 								switch(param.expr) {
	// 									case EObjectDecl(expr):
	// 										for (metaObjectField in expr) {
	// 											if (metaObjectField.field == 'alias') {
	// 												switch(metaObjectField.expr.expr) {
	// 													case EConst(CString(s)):definition.alias = s;
	// 													default: MacroContext.error('$className.${field.name}: rpc metadata ' + "'alias' field must be a String.", pos);
	// 												}
	// 											} else if (metaObjectField.field == 'argumentDocs') {
	// 												switch(metaObjectField.expr.expr) {
	// 													case EObjectDecl(objectDeclaration):
	// 														for (objectItemExpr in objectDeclaration) {
	// 															switch(objectItemExpr.expr.expr) {
	// 																case EConst(CString(s)):
	// 																	var docKey = objectItemExpr.field.substr("@$__hx__".length);
	// 																	var arg :RemoteMethodArgument = definition.args.find(function(v) return v.name == docKey);
	// 																	if (arg == null) {
	// 																		MacroContext.error('$className.${field.name}: rpc metadata ' + "'docs' values: there is no matching method argument '" + docKey + "'", pos);
	// 																	}
	// 																	arg.doc = s;
	// 																default: MacroContext.error('$className.${field.name}: rpc metadata ' + "'docs' values must be Strings", pos);
	// 															}
	// 														}
	// 													default: MacroContext.error('$className.${field.name}: rpc metadata ' + "'docs' field must be an Object.", pos);
	// 												}
	// 											} else if (metaObjectField.field == 'methodDoc') {
	// 												switch(metaObjectField.expr.expr) {
	// 													case EConst(CString(s)):
	// 														definition.doc = s;
	// 													default: MacroContext.error('$className.${field.name}: rpc metadata ' + "'doc' field must be an String.", pos);
	// 												}
	// 											} else if (metaObjectField.field == 'short') {
	// 												switch(metaObjectField.expr.expr) {
	// 													case EObjectDecl(objectDeclaration):
	// 														for (objectItemExpr in objectDeclaration) {
	// 															switch(objectItemExpr.expr.expr) {
	// 																case EConst(CString(s)):
	// 																	var argKey = objectItemExpr.field.substr("@$__hx__".length);
	// 																	var arg :RemoteMethodArgument = definition.args.find(function(v) return v.name == argKey);
	// 																	if (arg == null) {
	// 																		MacroContext.error('$className.${field.name}: rpc metadata ' + "'short' values: there is no matching method argument '" + argKey + "'", pos);
	// 																	}
	// 																	if (s.length != 1) {
	// 																		MacroContext.error('$className.${field.name}: rpc metadata ' + "'short' values must be a string of length=1, '" + s + "'.length=" + s.length, pos);
	// 																	}
	// 																	arg.short = s;
	// 																default: MacroContext.error('$className.${field.name}: rpc metadata ' + "'docs' values must be Strings", pos);
	// 															}
	// 														}
	// 													default: MacroContext.error('$className.${field.name}: rpc metadata ' + "'docs' field must be an Object.", pos);
	// 												}
	// 											} else {
	// 												MacroContext.error('$className.${field.name}: Unrecognized field (${metaObjectField.field}) in rpc metadata. Allows fields=[aliases, docs]', pos);
	// 											}
	// 										}
	// 									default:
	// 										MacroContext.error("The rpc metadata must be an object formatted e.g. {'alias':['alias1', 'alias2'], 'docs':{'argumentName1':'argumentDocString1', 'argumentName2':'argumentDocString2'}}. All fields are optional", pos);
	// 								}
	// 							}
	// 						}
	// 						functionArgs = args;
	// 					default: throw '"@$metaKey" metadata on a variable ${field.name}, only allowed on methods.';
	// 				}

	// 				switch(field.kind) {
	// 					case FMethod(k):
	// 					default: throw '"@$metaKey" metadata on a variable ${field.name}, only allowed on methods.';
	// 				}
	// 			}
	// 		}
	// 	}
	// 	return macro $v {remoteDefinitions};
	// }
}