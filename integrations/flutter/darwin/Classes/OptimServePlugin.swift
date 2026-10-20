import Foundation
import OptimServe
#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif
public final class OptimServePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var session: OptimServeSession?, sink: FlutterEventSink?
    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = OptimServePlugin()
        #if os(macOS)
        let messenger = registrar.messenger
        #else
        let messenger = registrar.messenger()
        #endif
        let channel = FlutterMethodChannel(name: "optimserve/methods", binaryMessenger: messenger)
        registrar.addMethodCallDelegate(plugin, channel: channel)
        FlutterEventChannel(name: "optimserve/events", binaryMessenger: messenger).setStreamHandler(plugin)
    }
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        do {
            if call.method == "configure" {
                guard let key = args["key"] as? String, let name = args["name"] as? String, let id = args["id"] as? String else { result(FlutterError(code: "OPTIMSERVE", message: "Provide your app information.", details: nil)); return }
                session?.close(); let core = try OptimServeSession(appKey: key, appName: name, appIdentifier: id); session = core
                core.onEvent = { [weak self] event in self?.sink?(event) }; result(nil); return
            }
            if call.method == "close" { session?.close(); session = nil; result(nil); return }
            guard let session = session else { result(FlutterError(code: "OPTIMSERVE", message: "Create the OptimServe session first.", details: nil)); return }
            switch call.method {
            case "prepare":
                guard let url = args["url"] as? String else { result(FlutterError(code: "OPTIMSERVE", message: "Provide an HTTPS media URL.", details: nil)); return }
                session.prepare(url, streamID: args["streamId"] as? String) { value, error in if let error = error { result(FlutterError(code: "OPTIMSERVE", message: error.localizedDescription, details: nil)) } else { result(value) } }
            case "updatePlayback": session.updatePlayback(args["state"] as? String ?? "paused", bufferedMs: args["buffered"] as? Double ?? 0, positionMs: args["position"] as? Double ?? 0); result(nil)
            case "setBackground": session.setBackground(args["value"] as? Bool ?? true); result(nil)
            case "snapshot": result(session.snapshot())
            case "stop": session.stop(); result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        } catch { result(FlutterError(code: "OPTIMSERVE", message: "Check your App Key and App ID.", details: nil)) }
    }
    deinit { let core = session; DispatchQueue.main.async { core?.close() } }
}
