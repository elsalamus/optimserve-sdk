import Foundation
import React
import OptimServe
@objc(OptimServe) final class OptimServeModule: RCTEventEmitter {
    private var session: OptimServeSession?, listening = false
    override static func requiresMainQueueSetup() -> Bool { true }
    override var methodQueue: DispatchQueue! { DispatchQueue.main }
    override func supportedEvents() -> [String]! { ["OptimServeEvent"] }
    override func startObserving() { listening = true }
    override func stopObserving() { listening = false }
    @objc func configure(_ key: String, name: String, identifier: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do { session?.close(); let core = try OptimServeSession(appKey: key, appName: name, appIdentifier: identifier); session = core
            core.onEvent = { [weak self] event in guard let self = self, self.listening else { return }; self.sendEvent(withName: "OptimServeEvent", body: event) }; resolve(nil)
        } catch { reject("OPTIMSERVE", "Check your App Key and App ID.", error) }
    }
    @objc func prepare(_ url: String, streamID: String?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let session = session else { reject("OPTIMSERVE", "Create the OptimServe session first.", nil); return }
        session.prepare(url, streamID: streamID) { result, error in if let error = error { reject("OPTIMSERVE", error.localizedDescription, error) } else { resolve(result) } }
    }
    @objc func updatePlayback(_ state: String, buffered: Double, position: Double, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { session?.updatePlayback(state, bufferedMs: buffered, positionMs: position); resolve(nil) }
    @objc func setBackground(_ value: Bool, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { session?.setBackground(value); resolve(nil) }
    @objc func snapshot(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(session?.snapshot()) }
    @objc func stop(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { session?.stop(); resolve(nil) }
    @objc func close(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { session?.close(); session = nil; resolve(nil) }
    deinit { let core = session; DispatchQueue.main.async { core?.close() } }
}
