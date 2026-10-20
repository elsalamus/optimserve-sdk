import Foundation
import Network
import SwarmCloudKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// One active stream per process, matching the pinned engine's ownership model.
@objc(OSSession) public final class OptimServeSession: NSObject, PlayerInteractor, EngineErrorMonitor {
    public static let version = "0.1.0"
    private static weak var owner: OptimServeSession?
    private let base = "https://p2p.optimserve.agency"
    private let key: String, name: String, identifier: String, appID: String
    private var grant = [String: Any](), stream = "", mode = "http", reason = "idle"
    private var monitor: P2pStatisticsMonitor?, timer: Timer?, request: URLSessionDataTask?
    private var generation = 0, sequence = 0, peers = 0, settingsVersion = 0
    private var http = 0, peer = 0, upload = 0, play = 0, buffer = 0, errors = 0, rebuffers = 0
    private var state = "paused", started = false, busy = false, reporting = false, closed = false
    private var lastTick = ProcessInfo.processInfo.systemUptime, checked = 0.0, expires = 0.0, renewAt = 0.0
    private var buffered = 0.0, position = 0.0
    private var observers = [NSObjectProtocol]()
    private let pathMonitor = NWPathMonitor()
    @objc public var onEvent: (([String: Any]) -> Void)?
    @objc public var onJSONEvent: ((String) -> Void)?
    private func emit(_ event: [String: Any]) { onEvent?(event); if let data = try? JSONSerialization.data(withJSONObject: event), let json = String(data: data, encoding: .utf8) { onJSONEvent?(json) } }
    public var queue: DispatchQueue { .main }

    @objc public init(appKey: String, appName: String, appIdentifier: String) throws {
        guard appKey.range(of: "^opa_[a-fA-F0-9]{32}_[a-fA-F0-9]{64}$", options: .regularExpression) != nil,
              !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, appName.count <= 80,
              appIdentifier.range(of: "^[A-Za-z0-9._-]{1,160}$", options: .regularExpression) != nil else {
            throw Self.error("Copy your App Key and App ID from OptimServe.")
        }
        key = appKey; name = appName; identifier = appIdentifier
        let raw = String(appKey.dropFirst(4).prefix(32))
        let cuts = [8, 12, 16, 20]
        appID = raw.enumerated().map { (cuts.contains($0.offset) ? "-" : "") + String($0.element) }.joined()
        super.init()
        pathMonitor.pathUpdateHandler = { [weak self] path in self?.metered = path.isExpensive || path.isConstrained }
        pathMonitor.start(queue: .main)
        #if canImport(UIKit)
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.setBackground(true) })
        #elseif canImport(AppKit)
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.setBackground(true) })
        #endif
    }
    private static func error(_ message: String) -> NSError { NSError(domain: "OptimServe", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    private static var platform: String {
        #if os(tvOS)
        return "tvos"
        #elseif os(macOS)
        return "macos"
        #else
        return "ios"
        #endif
    }
    private func endpoint(_ address: String) -> URL? {
        guard let url = URL(string: address), url.scheme == "https", url.host == "p2p.optimserve.agency",
              url.port == nil, url.user == nil, url.password == nil, url.fragment == nil, url.query == nil,
              url.path.range(of: "^/api/native/(apps/[a-fA-F0-9-]{36}/sessions|sessions/[a-fA-F0-9]{64}/(renew|reports|stop|configuration))$", options: .regularExpression) != nil else { return nil }
        return url
    }
    private func post(_ address: String, _ body: [String: Any], completion: @escaping ([String: Any]?) -> Void) -> URLSessionDataTask? {
        guard let url = endpoint(address), let data = try? JSONSerialization.data(withJSONObject: body) else { completion(nil); return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = data
        // Disable shared cookies, caches and redirects: capability URLs remain first-party only.
        let config = URLSessionConfiguration.ephemeral; config.httpShouldSetCookies = false; config.urlCache = nil
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        let task = session.dataTask(with: req) { data, response, _ in
            session.finishTasksAndInvalidate()
            let result: [String: Any]?
            if let response = response as? HTTPURLResponse, response.statusCode == 200 || response.statusCode == 201,
               let data = data, data.count <= 131072 { result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] } else { result = nil }
            DispatchQueue.main.async { completion(result) }
        }; task.resume(); return task
    }
    @objc public func prepare(_ url: String, streamID: String?, completion: @escaping ([String: Any]?, NSError?) -> Void) {
        precondition(Thread.isMainThread)
        guard !closed, let media = URL(string: url), media.scheme == "https", media.host != nil,
              media.user == nil, media.password == nil, media.fragment == nil, url.utf8.count <= 2048,
              streamID == nil || streamID!.range(of: "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$", options: .regularExpression) != nil else { completion(nil, Self.error("Use an HTTPS media URL and a valid optional Stream ID.")); return }
        guard Self.owner == nil || Self.owner === self else { completion(nil, Self.error("Stop the other OptimServe session first.")); return }
        stop(); Self.owner = self; stream = url; generation += 1; let run = generation
        mode = "http"; reason = "authorizing"; sequence = 0; http = 0; peer = 0; upload = 0; play = 0; buffer = 0; errors = 0; rebuffers = 0; peers = 0
        state = "paused"; started = false; reporting = false; busy = false; lastTick = ProcessInfo.processInfo.systemUptime
        var body: [String: Any] = ["key": key, "app_name": name, "app_identifier": identifier, "platform": Self.platform, "stream": url, "selection": Int.random(in: 0..<100), "metered": true]
        body["metered"] = metered
        if let streamID = streamID { body["stream_id"] = streamID }
        request = post(base + "/api/native/apps/" + appID + "/sessions", body) { [weak self] result in
            guard let self = self else { return }
            guard self.generation == run, !self.closed else { if let stop = result?["stop"] as? String { _ = self.post(stop, [:]) { _ in } }; completion(nil, Self.error("Playback setup was cancelled.")); return }
            self.request = nil
            guard let result = result, self.valid(result) else { self.reason = "authorization_unavailable"; completion(["url": url, "mode": "http", "reason": self.reason], nil); return }
            self.grant = result; self.expires = ProcessInfo.processInfo.systemUptime + 590; self.renewAt = ProcessInfo.processInfo.systemUptime + 480
            let settings = result["settings"] as! [String: Any]; self.settingsVersion = settings["version"] as? Int ?? 0
            self.mode = result["mode"] as? String ?? "http"; self.reason = result["reason"] as? String ?? "http"
            var playback = url
            if self.mode == "p2p" {
                if result["ad"] != nil && !(result["ad"] is NSNull) || !(settings["segment_bypass_paths"] as? [String] ?? []).isEmpty { self.mode = "http"; self.reason = "player_policy_unavailable" }
                else { playback = self.startEngine(result, url) }
            }
            self.checked = ProcessInfo.processInfo.systemUptime
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
            completion(["url": playback, "mode": self.mode, "reason": self.reason], nil)
        }
    }
    @objc public var metered = true
    @objc public func prepareJSON(_ stream: String, streamID: String?, completion: @escaping (String?, String?) -> Void) {
        prepare(stream, streamID: streamID) { result, error in
            guard let result = result, let data = try? JSONSerialization.data(withJSONObject: result), let json = String(data: data, encoding: .utf8) else { completion(nil, error?.localizedDescription ?? "Playback setup failed."); return }
            completion(json, nil)
        }
    }
    @objc public func snapshotJSON() -> String { guard let data = try? JSONSerialization.data(withJSONObject: snapshot()) else { return "{}" }; return String(data: data, encoding: .utf8) ?? "{}" }
    private func valid(_ result: [String: Any]) -> Bool {
        guard ["http", "p2p"].contains(result["mode"] as? String ?? ""), result["expiresIn"] as? Int == 600,
              let settings = result["settings"] as? [String: Any], (settings["version"] as? Int ?? 0) > 0 else { return false }
        for field in ["renew", "report", "configuration", "stop"] { guard let value = result[field] as? String, endpoint(value) != nil else { return false } }
        if result["mode"] as? String == "p2p" {
            guard let announce = result["announce"] as? String, let url = URL(string: announce), url.scheme == "https", url.host == "p2p.optimserve.agency", url.path.range(of: "^/api/native/sessions/[a-f0-9]{64}/v1$", options: .regularExpression) != nil,
                  let signal = result["signalConfig"] as? [String: Any], let main = signal["main"] as? String, let socket = URL(string: main), socket.scheme == "wss", socket.host == "p2p.optimserve.agency", socket.path.range(of: "^/api/native/signal/[a-f0-9]{64}$", options: .regularExpression) != nil,
                  result["channelId"] is String, result["token"] is String else { return false }
        }
        return true
    }
    private func startEngine(_ result: [String: Any], _ original: String) -> String {
        let settings = result["settings"] as! [String: Any], config = P2pConfig()
        config.announce = result["announce"] as? String; config.announces = [config.announce!]
        config.signalConfig = SignalConfig(mainAddr: (result["signalConfig"] as! [String: Any])["main"] as? String, backupAddr: nil)
        config.geoIpPreflight = false; config.ICEPreflight = false; config.p2pProtocolVersion = .V8
        config.iceServers = [IceServer(url: "stun:stun.l.google.com:19302"), IceServer(url: "stun:global.stun.twilio.com:3478")]
        config.diskCacheLimit = 0; config.memoryCacheCountLimit = 10; config.sharePlaylist = false; config.debug = false
        config.useHttpRange = settings["use_http_range"] as? Bool ?? true; config.prefetchOnly = settings["prefetch_only"] as? Bool ?? false
        P2pEngine.setup(token: result["token"] as! String, config: config)
        P2pEngine.shared.playerInteractor = self; P2pEngine.shared.registerEngineErrorMonitor(self)
        let stats = P2pStatisticsMonitor(queue: .main); monitor = stats; P2pEngine.shared.p2pStatisticsMonitor = stats
        let run = generation
        stats.onHttpDownloaded = { [weak self] value in guard let self = self, self.generation == run, self.mode == "p2p", value > 0 else { return }; self.http += value }
        stats.onP2pDownloaded = { [weak self] value, _ in guard let self = self, self.generation == run, self.mode == "p2p", value > 0 else { return }; self.peer += value }
        stats.onP2pUploaded = { [weak self] value in guard let self = self, self.generation == run, self.mode == "p2p", value > 0 else { return }; self.upload += value }
        stats.onPeers = { [weak self] peers in guard let self = self, self.generation == run, self.mode == "p2p" else { return }; self.peers = peers.count }
        do { try P2pEngine.shared.startLocalServer() } catch { fallback("proxy_unavailable"); return original }
        return P2pEngine.shared.parseStreamUrl(original, videoId: result["channelId"] as? String)
    }
    private func countTime() {
        let now = ProcessInfo.processInfo.systemUptime, elapsed = Int(max(0, min(now - lastTick, 2)) * 1000); lastTick = now
        if state == "playing" { play += elapsed; started = true }; if state == "buffering" { buffer += elapsed }
    }
    @objc public func updatePlayback(_ value: String, bufferedMs: Double, positionMs: Double) {
        precondition(Thread.isMainThread); guard ["playing", "paused", "buffering", "stopped"].contains(value) else { return }
        countTime(); if value == "buffering" && state != value && started { rebuffers = min(100000, rebuffers + 1) }; state = value
        buffered = bufferedMs.isFinite ? max(0, bufferedMs / 1000) : 0; position = positionMs.isFinite ? max(0, positionMs / 1000) : 0
    }
    @objc public func setBackground(_ background: Bool) {
        precondition(Thread.isMainThread)
        if background && ((grant["settings"] as? [String: Any])?["hide_background_p2p"] as? Bool ?? false) { fallback("background_paused") }
    }
    @objc public func snapshot() -> [String: Any] {
        ["http_kib": mode == "p2p" || http > 0 ? http as Any : NSNull(), "peer_kib": peer, "upload_kib": upload, "play_ms": play, "buffer_ms": buffer, "peers": peers, "mode": mode, "reason": reason, "reporting": reporting]
    }
    private func report(_ final: Bool) -> [String: Any] {
        sequence += 1
        return ["sequence": sequence, "http_kib": http, "peer_kib": peer, "upload_kib": upload, "play_ms": play, "buffer_ms": buffer, "rebuffers": rebuffers, "errors": errors, "started": started, "state": final ? "stopped" : state,
                "runtime": ["sdk": "3.6.1", "adapter": "native", "adapter_version": Self.version, "player": "player"]]
    }
    private func tick() {
        countTime(); emit(["type": "stats", "stats": snapshot()]); let now = ProcessInfo.processInfo.systemUptime
        if now >= expires { fallback("session_expired") }
        guard !busy, now - checked >= 10, let reportURL = grant["report"] as? String else { return }
        checked = now; busy = true; let run = generation; let payload = report(false)
        _ = post(reportURL, payload) { [weak self] result in
            guard let self = self, self.generation == run else { return }; self.reporting = result != nil
            guard result != nil else { self.busy = false; self.fallback("reporting_unavailable"); return }
            let renewing = now >= self.renewAt; let url = self.grant[renewing ? "renew" : "configuration"] as! String
            _ = self.post(url, self.mode == "p2p" ? [:] : ["p2p": false]) { [weak self] next in
                guard let self = self, self.generation == run else { return }; self.busy = false
                guard let next = next else { self.fallback("access_check_unavailable"); return }
                if renewing {
                    guard next["expiresIn"] as? Int == 600, next["session_id"] as? String == self.grant["session_id"] as? String else { self.fallback("renewal_invalid"); return }
                    self.expires = ProcessInfo.processInfo.systemUptime + 590; self.renewAt = ProcessInfo.processInfo.systemUptime + 480
                }
                if next["mode"] as? String != "p2p" || (next["settings"] as? [String: Any])?["version"] as? Int != self.settingsVersion { self.fallback("delivery_settings_changed") }
            }
        }
    }
    private func fallback(_ why: String) {
        guard mode == "p2p" else { return }; mode = "http"; reason = why; peers = 0
        P2pEngine.shared.disableP2p(); P2pEngine.shared.stopP2p()
        emit(["type": "url", "url": stream, "mode": mode, "reason": reason])
    }
    @objc public func stop() {
        precondition(Thread.isMainThread); countTime(); generation += 1; request?.cancel(); request = nil; timer?.invalidate(); timer = nil
        if Self.owner === self { P2pEngine.shared.disableP2p(); P2pEngine.shared.stopP2p(); P2pEngine.shared.unregisterEngineErrorMonitor(); P2pEngine.shared.playerInteractor = nil; P2pEngine.shared.p2pStatisticsMonitor = nil; Self.owner = nil }
        monitor = nil; let previous = grant; grant = [:]; mode = "http"; state = "stopped"
        if let url = previous["report"] as? String { _ = post(url, report(true)) { [weak self] _ in if let stop = previous["stop"] as? String { _ = self?.post(stop, [:]) { _ in } } } }
    }
    @objc public func close() { stop(); closed = true; pathMonitor.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) }; observers = []; onEvent = nil; onJSONEvent = nil }
    public func onBufferedDuration() -> TimeInterval { buffered }
    public func onCurrentPosition() -> TimeInterval { position }
    public func onTrackerException(_ reason: String?) { fallback("tracker_unavailable") }
    public func onSignalException(_ reason: String?) { fallback("signaling_unavailable") }
    public func onSchedulerException(_ reason: String?) { fallback("peer_unavailable") }
    public func onOtherException(_ reason: String?) { fallback("peer_unavailable") }
    deinit { pathMonitor.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
}
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
