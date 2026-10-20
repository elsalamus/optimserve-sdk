import Foundation
import AVFoundation

@objc(OSPlayer) public final class OptimServePlayer: NSObject {
    @objc public let player = AVPlayer()
    private let session: OptimServeSession
    private var observation: Any?, generation = 0, closed = false
    @objc public var onEvent: (([String: Any]) -> Void)?
    @objc public init(appKey: String, appName: String, appIdentifier: String) throws {
        session = try OptimServeSession(appKey: appKey, appName: appName, appIdentifier: appIdentifier)
        super.init()
        session.onEvent = { [weak self] event in
            guard let self = self else { return }
            if event["type"] as? String == "url", let address = event["url"] as? String, let url = URL(string: address) {
                let position = self.player.currentTime(), resume = self.player.rate > 0
                let seek = self.player.currentItem?.duration.seconds.isFinite == true
                self.player.replaceCurrentItem(with: AVPlayerItem(url: url))
                if seek { self.player.seek(to: position) }; if resume { self.player.play() }
            }
            self.onEvent?(event)
        }
        observation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1000), queue: .main) { [weak self] _ in
            guard let self = self, !self.closed else { return }
            let current = self.player.currentTime().seconds
            let buffered = self.player.currentItem?.loadedTimeRanges.compactMap { value -> Double? in
                let range = value.timeRangeValue, start = range.start.seconds, end = CMTimeRangeGetEnd(range).seconds
                return current >= start && current <= end ? max(0, end - current) : nil
            }.first ?? 0
            let state = self.player.timeControlStatus == .playing ? "playing" : self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate ? "buffering" : "paused"
            self.session.updatePlayback(state, bufferedMs: buffered * 1000, positionMs: current.isFinite ? current * 1000 : 0)
        }
    }
    @objc public func play(_ url: String, streamID: String?) {
        precondition(Thread.isMainThread); guard !closed else { return }; generation += 1; let run = generation
        session.prepare(url, streamID: streamID) { [weak self] result, error in
            guard let self = self, self.generation == run, !self.closed else { return }
            guard let address = result?["url"] as? String, let media = URL(string: address) else { self.onEvent?(["type":"error","message":error?.localizedDescription ?? "Playback setup failed."]); return }
            self.player.replaceCurrentItem(with: AVPlayerItem(url: media)); self.player.play()
        }
    }
    @objc public func stop() { precondition(Thread.isMainThread); generation += 1; player.pause(); player.replaceCurrentItem(with: nil); session.stop() }
    @objc public func close() { precondition(Thread.isMainThread); guard !closed else { return }; stop(); closed = true; if let observation = observation { player.removeTimeObserver(observation) }; observation = nil; session.close(); onEvent = nil }
}
