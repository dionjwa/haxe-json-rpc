package js.npm;

import js.html.Float32Array;

import js.Node;
import js.node.http.Server;
import js.node.events.EventEmitter;

typedef Config = {
    var protocolVersion :Int;
    var origin :String;
}

typedef ServerConfig = {
    var port :Int;
}

typedef ReceiveFlags = {
    var binary :Bool;
    var masked :Bool;
}
typedef SendFlags = {
    var mask :Bool;
}

extern class WebSocket extends EventEmitter
    implements npm.Package.Require<"ws","*">
{
    public static var CONNECTING :Int;
    public static var OPEN :Int;
    public static var CLOSING :Int;
    public static var CLOSED :Int;

    public var readyState :Int;
    public var url :String;

    public function new(host:String, ?protocols :Dynamic, ?config :Config) :Void;

    public var onopen :Void->Void;
    public var onerror :Dynamic->Void;
    public var onclose :Int->Dynamic->Void;

    @:overload( function(data :Float32Array, flags:ReceiveFlags) :Void {})
    dynamic public function onmessage(data :String, flags:ReceiveFlags) :Void;


    @:overload( function( data : Float32Array, ?cb :Dynamic->Void) :Void {})
    public function send(data :String, ?cb :Dynamic->Void) :Void;

    public function close(?code :Int, ?data :Dynamic) :Void;
    public function terminate() :Void;

    public function ping(?data :Dynamic, ?options:{mask :Bool, binary:Bool}, ?dontFailWhenClosed :Bool) :Void;
    public function pong(?data :Dynamic, ?options:{mask :Bool, binary:Bool}, ?dontFailWhenClosed :Bool) :Void;

    public function pause() :Void;
    public function resume() :Void;
}

@:native("Server")
extern class WebSocketServer extends EventEmitter
    implements npm.Package.RequireNamespace<"ws","*">
{
    public var clients :Array<WebSocket>;

    public function new(config :ServerConfig, ?cb :Void->Void) :Void;

    @:overload( function( data : Float32Array, ?cb :Dynamic->Void) :Void {})
    public function send(data :String, ?cb :Dynamic->Void) :Void;

    public function onConnection(cb :WebSocket->Void) :Void;
    public function close() :Void;
}

class Constants
{
    inline public static var EVENT_CONNECTION = 'connection';
    inline public static var EVENT_OPEN = 'open';
    inline public static var EVENT_MESSAGE = 'message';
    inline public static var EVENT_CLOSE = 'close';
    inline public static var EVENT_ERROR = 'error';
}