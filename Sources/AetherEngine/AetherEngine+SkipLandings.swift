import Foundation

// AIOStreams fork: the bytes a skip lands on, held ahead of the skip.

extension AetherEngine {
    /// Tells the source reader where the host may skip to ("Skip intro", "Skip recap"), as times on
    /// the source axis, the one `seek(to:)` takes. The reader fetches the bytes there in the
    /// background while the link can spare them, so a skip is served from memory and the stream is
    /// connecting by the time they are read out. Replaces the previous set; an empty array clears it.
    /// Does nothing for a source with no network reader (a local file, a disc, live).
    ///
    /// A Matroska file's index is read on the first seek, so times the index doesn't cover yet are
    /// tried again after 2, 5, 15 and 30 seconds, until another call replaces them.
    public func prefetchLandings(atSeconds seconds: [Double]) {
        let times = seconds.filter { $0.isFinite && $0 >= 0 }
        guard let demuxer = softwareHost?.pumpDemuxer ?? nativeVideoSession?.demuxer else { return }
        if times.isEmpty {
            demuxer.setLandings(seconds: [])
            return
        }
        if demuxer.setLandings(seconds: times) { return }
        let session = ObjectIdentifier(demuxer)
        Task { @MainActor [weak self] in
            for delay in [2.0, 5.0, 15.0, 30.0] {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let self,
                      let current = self.softwareHost?.pumpDemuxer ?? self.nativeVideoSession?.demuxer,
                      ObjectIdentifier(current) == session,
                      current.requestedLandingSeconds == times else { return }
                if current.setLandings(seconds: times) { return }
            }
        }
    }
}
