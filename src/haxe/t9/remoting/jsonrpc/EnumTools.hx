package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;

class EnumTools
{
	static public function enumToRequest(e :EnumValue) :RequestDef
	{
		return {
			method: Type.enumConstructor(e),
			params: Type.enumParameters(e)
		};
	}

	static public function requestToEnum<T>(e :Enum<T>, request :RequestDef) :T
	{
		return Type.createEnum(e, request.method, request.params);
	}
}