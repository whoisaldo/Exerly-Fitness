import Foundation
import Observation
import WatchConnectivity

/// The watch's end of the link: the phone's last state and the commands it
/// hasn't handled yet, both kept across launches. Commands go one message at
/// a time while the phone is reachable, otherwise as user info transfers,
/// which the system delivers in order. Once one goes as a transfer, later
/// ones follow it until it's delivered, so none overtakes another.
@MainActor
@Observable
final class PhoneLink: NSObject {
    static let shared = PhoneLink()

    /// The phone's last state.
    private(set) var state: WatchState?
    /// Commands the phone hasn't handled, oldest first.
    private(set) var pending: [WatchCommand] = []
    private(set) var isReachable = false
    @ObservationIgnored private var sent: Set<UUID> = []
    @ObservationIgnored private var awaitingReply = false
    @ObservationIgnored private let defaults = UserDefaults.standard

    /// What to show: the phone's state with the watch's own commands applied.
    func display(at now: Date) -> WatchState? { state?.predicting(pending, at: now) }

    /// A start is waiting for the phone.
    var isStarting: Bool { pending.contains { $0.action == .start } }

    func activate() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            defaults.removeObject(forKey: "watch.state")
            defaults.removeObject(forKey: "watch.pending")
        }
        #endif
        state = defaults.data(forKey: "watch.state").flatMap { try? JSONDecoder().decode(WatchState.self, from: $0) }
        pending = defaults.data(forKey: "watch.pending").flatMap { try? JSONDecoder().decode([WatchCommand].self, from: $0) } ?? []
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ action: WatchCommand.Action, for workoutID: UUID?) {
        pending.append(WatchCommand(workoutID: workoutID, action: action))
        save()
        flush()
    }

    private func flush() {
        let session = WCSession.default
        guard session.activationState == .activated, !awaitingReply else { return }
        let unsent = pending.filter { !sent.contains($0.id) }
        guard let next = unsent.first else { return }
        if session.isReachable, session.outstandingUserInfoTransfers.isEmpty {
            sent.insert(next.id)
            awaitingReply = true
            session.sendMessage(WatchLink.payload(next), replyHandler: { reply in
                Task { @MainActor in
                    self.awaitingReply = false
                    // An empty reply means the phone couldn't run it; don't keep showing it.
                    if WatchLink.state(from: reply) == nil { self.pending.removeAll { $0.id == next.id } }
                    self.receive(reply)
                    self.flush()
                }
            }, errorHandler: { _ in
                Task { @MainActor in
                    self.awaitingReply = false
                    // The phone may have run it anyway; it ignores a command it has seen.
                    session.transferUserInfo(WatchLink.payload(next))
                    self.flush()
                }
            })
        } else {
            for command in unsent {
                sent.insert(command.id)
                session.transferUserInfo(WatchLink.payload(command))
            }
        }
    }

    private func receive(_ payload: [String: Any]) {
        if let new = WatchLink.state(from: payload), new.revision > state?.revision ?? 0 {
            state = new
            if let handled = new.handled, let index = pending.firstIndex(where: { $0.id == handled }) {
                pending.removeFirst(index + 1)
            }
        }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(state), forKey: "watch.state")
        defaults.set(try? JSONEncoder().encode(pending), forKey: "watch.pending")
    }

    private func refresh(_ session: WCSession) {
        isReachable = session.isReachable
        flush()
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.receive(context)
            self.refresh(session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in self.receive(context) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh(session) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in self.refresh(session) }
    }
}
