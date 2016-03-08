package t9.remoting.jsonrpc.cli;

import haxe.remoting.JsonRpc;
import js.npm.Commander;

using Lambda;

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
			var commandName = definition.method;
			for (arg in definition.args.filter(function(v) return !v.optional)) {
				commandName += ' <${arg.name}>';
			}
			var command = program.command(commandName);
			command.description(definition.doc);
			if (definition.alias != null) {
				command.alias(definition.alias);
			}
			for (arg in definition.args.filter(function(v) return v.optional)) {
				var optionalArgString = '--${arg.name} [${arg.name}]';
				if (arg.short != null) {
					optionalArgString = '-${arg.short}, ' + optionalArgString;
				}
				command.option(optionalArgString, arg.doc);
			}

			command.action(function(arg1 :Dynamic, arg2 :Dynamic, arg3 :Dynamic, arg4 :Dynamic, arg5 :Dynamic, arg6 :Dynamic, arg7 :Dynamic) {
				var options :{options:Dynamic} = getOptions(arg1, arg2, arg3, arg4, arg5, arg6, arg7);
				var arguments = getArguments(arg1, arg2, arg3, arg4, arg5, arg6, arg7);
				var request :RequestDef = {
					jsonrpc: '2.0',
					method: definition.method,
					params: {}
				}
				var requiredArgs = definition.args.filter(function(v) return !v.optional).array();
				var optionalArgs = definition.args.filter(function(v) return v.optional).array();
				for (i in 0...requiredArgs.length) {
					Reflect.setField(request.params, requiredArgs[i].name, arguments[i]);
				}
				for (arg in optionalArgs) {
					if (Reflect.hasField (command, arg.name)) {
						Reflect.setField(request.params, arg.name, Reflect.field(command, arg.name));
					}
				}
				jsonrpcCallback(request);
			});
		}
	}

	/**
	 * Haxe doesn't have good ways of collapsing function arguments
	 */
	static function getOptions(arg1 :Dynamic, arg2 :Dynamic, arg3 :Dynamic, arg4 :Dynamic, arg5 :Dynamic, arg6 :Dynamic, arg7 :Dynamic)
	{
		if (arg7 == null) {
			if (arg6 == null) {
				if (arg5 == null) {
					if (arg4 == null) {
						if (arg3 == null) {
							if (arg2 == null) {
								if (arg1 == null) {
									trace('Should not be here');
									return null;
								} else {
									return arg1;
								}
							} else {
								return arg2;
							}
						} else {
							return arg3;
						}
					} else {
						return arg4;
					}
				} else {
					return arg5;
				}
			} else {
				return arg6;
			}
		} else {
			return arg7;
		}
	}

	/**
	 * Haxe doesn't have good ways of collapsing function arguments
	 */
	static function getArguments(arg1 :Dynamic, arg2 :Dynamic, arg3 :Dynamic, arg4 :Dynamic, arg5 :Dynamic, arg6 :Dynamic, arg7 :Dynamic)
	{
		if (arg7 == null) {
			if (arg6 == null) {
				if (arg5 == null) {
					if (arg4 == null) {
						if (arg3 == null) {
							if (arg2 == null) {
								if (arg1 == null) {
									trace('Should not be here');
									return null;
								} else {
									return [];
								}
							} else {
								return [arg1];
							}
						} else {
							return [arg1, arg2];
						}
					} else {
						return [arg1, arg2, arg3];
					}
				} else {
					return [arg1, arg2, arg3, arg4];
				}
			} else {
				return [arg1, arg2, arg3, arg4, arg5];
			}
		} else {
			return [arg1, arg2, arg3, arg4, arg5, arg6];
		}
	}
}