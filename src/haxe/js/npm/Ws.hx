package js.npm;

import haxe.DynamicAccess;
import haxe.io.Float32Array;

import js.Error;
import js.Node;
import js.node.http.IncomingMessage;
import js.node.http.Server;
import js.node.events.EventEmitter;

typedef Config = {
    var protocolVersion :Int;
    var origin :String;
}

typedef ServerConfig = {
    @:optional var port :Int;
    @:optional var host :String;
    @:optional var server :Server;
    @:optional var verifyClient :Dynamic;
    @:optional var handleProtocols :Dynamic;
    @:optional var path :String;
    @:optional var noServer :Bool;
    @:optional var disableHixie :Bool;
    @:optional var clientTracking :Bool;
    @:optional var perMessageDeflate :Bool;
}

typedef ReceiveFlags = {
    var binary :Bool;
    var masked :Bool;
}
typedef SendFlags = {
    var mask :Bool;
}

typedef Code=Int;
typedef Message=String;
typedef Flags={binary:Bool};
typedef Data=Dynamic;

/**
    Enumeration of events emitted by the `WebSocketServer` objects
**/
@:enum abstract WebSocketEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
    var Error : WebSocketEvent<Error->Void> = 'error';
    var Close : WebSocketEvent<Code->Message->Void> = 'close';
    var Message : WebSocketEvent<Data->Flags->Void> = 'message';
    var Ping : WebSocketEvent<Data->Flags->Void> = 'ping';
    var Pong : WebSocketEvent<Data->Flags->Void> = 'pong';
    var Open : WebSocketEvent<Void->Void> = 'open';
}

@:jsRequire('ws')
extern class WebSocket extends EventEmitter<WebSocket>
{
    public static var CONNECTING :Int;
    public static var OPEN :Int;
    public static var CLOSING :Int;
    public static var CLOSED :Int;

    public var readyState :Int;
    public var url :String;
    public var protocolVersion :String;
    public var supports :String;
    public var upgradeReq :DynamicAccess<String>;
    public var bytesReceived :Int;

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

/**
    Enumeration of events emitted by the `WebSocketServer` objects
**/
@:enum abstract WebSocketServerEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
    var Connection : WebSocketServerEvent<WebSocket->Void> = 'connection';
    var Headers : WebSocketServerEvent<DynamicAccess<String>->Void> = 'headers';
    var Error : WebSocketServerEvent<Error->Void> = 'error';
}

@:jsRequire('ws', 'Server')
extern class WebSocketServer extends EventEmitter<WebSocketServer>
{
    public var clients :Array<WebSocket>;

    public function new(config :ServerConfig, ?cb :Void->Void) :Void;

    @:overload( function( data : Float32Array, ?cb :Dynamic->Void) :Void {})
    public function send(data :String, ?cb :Dynamic->Void) :Void;

    public function onConnection(cb :WebSocket->Void) :Void;
    public function close() :Void;
}