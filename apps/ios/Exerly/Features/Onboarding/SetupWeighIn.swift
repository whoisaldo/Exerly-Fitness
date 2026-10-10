import ExerlyCore
import Foundation

/// The weight typed in setup becomes the first ExerlyCore weigh-in as soon as
/// the account's workspace opens, offline included, rather than waiting for
/// Today's import of older weigh-ins to find the server's copy. It takes the
/// ID that import gives the same day's reading, so the two never add it twice.
enum SetupWeighIn {
    private static func key(_ accountID: String, namespace: String) -> String {
        "setup.weighIn.v1.\(namespace).\(accountID)"
    }

    /// Call when setup completes. The day is the account's, like the server's.
    static func remember(accountID: String, kilograms: Double, timeZone: String,
                         namespace: String = APIClient.shared.storageNamespace, defaults: UserDefaults = .standard,
                         now: Date = Date()) {
        let zone = TimeZone(identifier: timeZone) ?? .current
        defaults.set(["kilograms": kilograms, "date": LocalDate(now, in: zone).description, "zone": zone.identifier],
                     forKey: key(accountID, namespace: namespace))
    }

    /// Writes a remembered setup weight once. A failed write is kept for the
    /// next time the workspace opens.
    @MainActor
    static func recordIfPending(_ workspace: TrainingWorkspace, namespace: String = APIClient.shared.storageNamespace,
                                defaults: UserDefaults = .standard) async {
        let key = key(workspace.accountID, namespace: namespace)
        guard let saved = defaults.dictionary(forKey: key) else { return }
        guard let kilograms = saved["kilograms"] as? Double, let day = saved["date"] as? String, let date = LocalDate(day) else {
            defaults.removeObject(forKey: key)
            return
        }
        let zone = (saved["zone"] as? String).flatMap(TimeZone.init(identifier:)) ?? .current
        do {
            let added = try workspace.nutrition.importLegacyWeights([LegacyWeighIn(date: date, kilograms: kilograms)],
                                                                    accountID: workspace.accountID, timeZone: zone)
            defaults.removeObject(forKey: key)
            if added > 0 { await workspace.synchronize() }
        } catch {}
    }
}
