import Foundation

/// Limits how many requests run at once and enforces a shared pause after a 429.
actor RequestLimiter {
    private let maxConcurrent: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var pausedUntil: Date?

    init(maxConcurrent: Int) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    /// Runs `operation` once a slot is free and no rate-limit pause is active.
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        if let pausedUntil, pausedUntil > .now {
            try await Task.sleep(for: .seconds(pausedUntil.timeIntervalSinceNow))
        }
        return try await operation()
    }

    /// Called after a 429 so that every queued request waits, not only the one that failed.
    func pause(for seconds: TimeInterval) {
        let until = Date.now.addingTimeInterval(seconds)
        if let pausedUntil, pausedUntil > until { return }
        pausedUntil = until
    }

    private func acquire() async {
        if running < maxConcurrent {
            running += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            running -= 1
        } else {
            // Hand the slot directly to the next waiter; `running` stays the same.
            waiters.removeFirst().resume()
        }
    }
}
