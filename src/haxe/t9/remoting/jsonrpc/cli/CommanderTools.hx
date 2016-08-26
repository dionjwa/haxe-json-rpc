package t9.remoting.jsonrpc.cli;

import haxe.remoting.JsonRpc;
import js.npm.commander.Commander;

using Lambda;
using StringTools;

class CommanderTools
{
	public static function handleQuotesInArgs(?rawArgs :Array<String> = null) :Array<String>
	{
		rawArgs = rawArgs == null ? js.Node.process.argv.copy() : rawArgs;
		var formatted = [];
		var isInQuotes = false;
		var quoteChar :String = null;
		while (rawArgs.length > 0) {
			if (isInQuotes) {
				var e = rawArgs.shift();
				formatted[formatted.length - 1] = formatted[formatted.length - 1] + ' ' + e;
				if (e.endsWith(quoteChar)) {
					isInQuotes = false;
				}
			} else {
				var e = rawArgs.shift();
				if (e.startsWith('"') || e.startsWith("'")) {
					isInQuotes = true;
					quoteChar = e.charAt(0);
				}
				formatted.push(e);
			}
		}
		return formatted;
	}

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
			var rawArgs :Array<String> = js.Node.process.argv.slice(2);
			var formatted = handleQuotesInArgs(rawArgs);
			program.parse(formatted);
		}

		return requestDef;
	}

	public static function addCommands(program :Commander, definitions :Array<RemoteMethodDefinition>, jsonrpcCallback :RequestDef->Void)
	{
		for (definition in definitions) {
			addCommand(program, definition, jsonrpcCallback);
		}
	}

	public static function addCommand(program :Commander, definition :RemoteMethodDefinition, jsonrpcCallback :RequestDef->Void)
	{
		var commandName = definition.alias != null ? definition.alias : definition.method;
		var nonOptionalArgs = definition.args.filter(function(v) return !v.optional);
		for (i in 0...nonOptionalArgs.length) {
			var arg = nonOptionalArgs[i];
			commandName += ' [${arg.name}]';
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

				command.option(optionalArgString, arg.doc, function(val, memo) {memo.push(val); trace('val=$val'); return memo;}, []);
			} else {
				command.option(optionalArgString, arg.doc, getConverter(arg.type));
			}
		}

		command.action(function(arg1 :Dynamic, arg2 :Dynamic, arg3 :Dynamic, arg4 :Dynamic, arg5 :Dynamic, arg6 :Dynamic, arg7 :Dynamic, arg8 :Dynamic, arg9 :Dynamic, arg10 :Dynamic, arg11 :Dynamic) {
			var arguments :Array<Dynamic> = untyped __js__('Array.prototype.slice.call(arguments)');
			arguments.pop();
			var request :RequestDef = {
				id: JsonRpcConstants.JSONRPC_NULL_ID,
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
				method: definition.alias != null ? definition.alias : definition.method,
				params: {}
			}
			var requiredArgs = definition.args.filter(function(v) return !v.optional).array();
			var optionalArgs = definition.args.filter(function(v) return v.optional).array();
			for (i in 0...requiredArgs.length) {
				var arg = requiredArgs[i];
				var converter = getConverter(arg.type);
				if (arg.type.startsWith('Array<') && i == (requiredArgs.length - 1) && arguments[i + 1] != null) {
					var arrArgs :Array<Dynamic> = arguments[i + 1];
					if (arguments[i] != null) {
						arrArgs.unshift(arguments[i]);
					}
					Reflect.setField(request.params, arg.name, arrArgs.map(converter));
				} else {
					Reflect.setField(request.params, arg.name, converter(arguments[i]));
				}
			}
			var rawArgs :Array<String> = command.parent.rawArgs;
			for (arg in optionalArgs) {
				if (Reflect.hasField(command, arg.name)) {
					Reflect.setField(request.params, arg.name, Reflect.field(command, arg.name));
				}
			}
			jsonrpcCallback(request);
		});
		if (definition.docCustom != null) {
			command.on('--help', function() {
				js.Node.process.stdout.write(definition.docCustom + '\n');
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
}