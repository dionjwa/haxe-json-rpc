package t9.remoting.jsonrpc.cli;

import haxe.remoting.JsonRpc;
import js.npm.Commander;

using Lambda;
using StringTools;

class CommanderTools
{
	public static function parseCliArgs(definitions :Array<RemoteMethodDefinition>) :RequestDef
	{
		var program :Commander = js.Node.require('commander');
		var requestDef :RequestDef = null;

		addCommands(program, definitions, function(def) {
			requestDef = def;
		});
		if (js.Node.process.argv.slice(2).length == 0) {
			program.outputHelp();
		} else {
			program.parse(js.Node.process.argv);
		}

		return requestDef;
	}

	public static function addCommands(program :Commander, definitions :Array<RemoteMethodDefinition>, jsonrpcCallback :RequestDef->Void)
	{
		for (definition in definitions) {
			var commandName = definition.alias != null ? definition.alias : definition.method;
			var nonOptionalArgs = definition.args.filter(function(v) return !v.optional);
			for (i in 0...nonOptionalArgs.length) {
				var arg = nonOptionalArgs[i];
				commandName += ' <${arg.name}>';
				if (i == (nonOptionalArgs.length - 1) && arg.type.startsWith('Array<')) {
					//Last argument can be variadic
					commandName += ' [more${arg.name}...]';
				}
			}
			var command = program.command(commandName);
			command.description(definition.doc);
			for (arg in definition.args.filter(function(v) return v.optional)) {
				var optionalArgString = '--${arg.name} [${arg.name}]';
				if (arg.short != null) {
					optionalArgString = '-${arg.short}, ' + optionalArgString;
				}
				if (arg.type.startsWith('Array<')) {
					var collectedVal = [];
					command.option(optionalArgString, arg.doc, function(val, memo) {memo.push(val); return memo;}, []);
				} else {
					command.option(optionalArgString, arg.doc, getConverter(arg.type));
				}
			}

			command.action(function(arg1 :Dynamic, arg2 :Dynamic, arg3 :Dynamic, arg4 :Dynamic, arg5 :Dynamic, arg6 :Dynamic, arg7 :Dynamic, arg8 :Dynamic, arg9 :Dynamic, arg10 :Dynamic, arg11 :Dynamic) {
				var arguments = getArguments(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11);
				var request :RequestDef = {
					id: JsonRpcConstants.JSONRPC_NULL_ID,
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
					method: definition.method,
					params: {}
				}
				var requiredArgs = definition.args.filter(function(v) return !v.optional).array();
				var optionalArgs = definition.args.filter(function(v) return v.optional).array();
				for (i in 0...requiredArgs.length) {
					var arg = requiredArgs[i];
					var converter = getConverter(arg.type);
					if (arg.type.startsWith('Array<') && i == (requiredArgs.length - 1) && arguments[i + 1] != null) {
						var arrArgs :Array<Dynamic> = arguments[i + 1];
						arrArgs.unshift(arguments[i]);
						Reflect.setField(request.params, arg.name, arrArgs.map(converter));
					} else {
						Reflect.setField(request.params, arg.name, converter(arguments[i]));
					}
				}
				for (arg in optionalArgs) {
					if (Reflect.hasField(command, arg.name)) {
						Reflect.setField(request.params, arg.name, Reflect.field(command, arg.name));
					}
				}
				jsonrpcCallback(request);
			});
		}
	}

	static function getConverter(type :String) :Dynamic->Dynamic
	{
		if (type.startsWith('Array<')) {
			type = type.replace('Array<', '').replace('>', '');
		}
		return switch(type) {
			case 'Int': Std.parseInt;
			case 'Float': Std.parseFloat;
			case 'Bool': function(val) {
				var s = val + '';
				return s == 'true' || s == 'True' || s == 'TRUE' || s == '1';
			}
			default: function(v) return v;
		}
	}

	/**
	 * Haxe doesn't have good ways of collapsing function arguments
	 */
	static function getArguments(arg1 :Dynamic, arg2 :Dynamic, arg3 :Dynamic, arg4 :Dynamic, arg5 :Dynamic, arg6 :Dynamic, arg7 :Dynamic, arg8 :Dynamic, arg9 :Dynamic, arg10 :Dynamic, arg11 :Dynamic)
	{
		if (arg11 == null && arg10 != null) {
			return [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9];
		} else if (arg10 == null && arg9 != null) {
			return [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8];
		} else if (arg9 == null && arg8 != null) {
			return [arg1, arg2, arg3, arg4, arg5, arg6, arg7];
		} else if (arg8 == null && arg7 != null) {
			return [arg1, arg2, arg3, arg4, arg5, arg6];
		} else if (arg7 == null && arg6 != null) {
			return [arg1, arg2, arg3, arg4, arg5];
		} else if (arg6 == null && arg5 != null) {
			return [arg1, arg2, arg3, arg4];
		} else if (arg5 == null && arg4 != null) {
			return [arg1, arg2, arg3];
		} else if (arg4 == null && arg3 != null) {
			return [arg1, arg2];
		} else if (arg3 == null && arg2 != null) {
			return [arg1];
		} else if (arg2 == null && arg1 != null) {
			return [];
		} else {
			trace('Should not be here');
			return [];
		}
	}
}