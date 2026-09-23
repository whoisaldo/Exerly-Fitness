import Foundation
import SwiftData

@Model
final class CachedFoodItem {
    @Attribute(.unique) var barcode: String?
    var name: String
    var brand: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var sugar: Double
    var fiber: Double
    var servingSize: String
    var isFavorite: Bool
    var isCustom: Bool
    var lastUsed: Date
    var createdAt: Date

    init(
        barcode: String? = nil, name: String, brand: String? = nil,
        calories: Int, protein: Double = 0, carbs: Double = 0,
        fat: Double = 0, sugar: Double = 0, fiber: Double = 0,
        servingSize: String = "100g", isFavorite: Bool = false,
        isCustom: Bool = false
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugar = sugar
        self.fiber = fiber
        self.servingSize = servingSize
        self.isFavorite = isFavorite
        self.isCustom = isCustom
        self.lastUsed = Date()
        self.createdAt = Date()
    }
}

@Model
final class DailyFoodLog {
    var foodName: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String
    var servingCount: Double
    var mealType: String
    var date: Date

    init(
        foodName: String, calories: Int, protein: Double = 0,
        carbs: Double = 0, fat: Double = 0, servingSize: String = "1 serving",
        servingCount: Double = 1, mealType: String = "snack", date: Date = .now
    ) {
        self.foodName = foodName
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingSize = servingSize
        self.servingCount = servingCount
        self.mealType = mealType
        self.date = date
    }
}

@Model
final class Measurement {
    var type: String
    var value: Double
    var unit: String
    var date: Date

    init(type: String, value: Double, unit: String, date: Date = .now) {
        self.type = type
        self.value = value
        self.unit = unit
        self.date = date
    }
}

@Model
final class ProgressPhoto {
    @Attribute(.externalStorage) var imageData: Data?
    var note: String?
    var date: Date
    var userId: String?

    init(imageData: Data? = nil, note: String? = nil, date: Date = .now, userId: String? = nil) {
        self.imageData = imageData
        self.note = note
        self.date = date
        self.userId = userId
    }
}

@Model
final class Achievement {
    @Attribute(.unique) var achievementId: String
    var title: String
    var desc: String
    var icon: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Double

    init(
        achievementId: String, title: String, desc: String,
        icon: String, isUnlocked: Bool = false, progress: Double = 0
    ) {
        self.achievementId = achievementId
        self.title = title
        self.desc = desc
        self.icon = icon
        self.isUnlocked = isUnlocked
        self.progress = progress
    }
}

@Model
final class OfflineAction {
    var endpoint: String
    var method: String
    var bodyData: Data?
    var createdAt: Date

    init(endpoint: String, method: String, bodyData: Data? = nil) {
        self.endpoint = endpoint
        self.method = method
        self.bodyData = bodyData
        self.createdAt = Date()
    }
}

// The original six model definitions remain unchanged so existing stores can
// migrate without guessing who owns previously unscoped records.
@Model
final class SyncedResource {
    @Attribute(.unique) var key: String
    var accountID: String
    var kind: String
    var entityID: String
    var serverID: String?
    var revision: Int
    var payload: Data
    var syncedPayload: Data?
    var syncState: String
    @Attribute(originalName: "deleted") var tombstoned: Bool
    var updatedAt: Date
    init(accountID: String, kind: String, entityID: String, payload: Data) {
        self.key = "\(accountID):\(kind):\(entityID)"
        self.accountID = accountID
        self.kind = kind
        self.entityID = entityID
        self.payload = payload
        revision = 0
        syncState = "pending"
        tombstoned = false
        updatedAt = Date()
    }
}

@Model
final class PendingMutation {
    @Attribute(.unique) var operationID: String
    var accountID: String
    var entityID: String
    var kind: String
    var method: String
    var endpoint: String
    var payload: Data
    var payloadVersion: Int
    var baseRevision: Int?
    var createdAt: Date
    var attempts: Int
    var state: String
    var lastError: String?
    var retryAt: Date?
    init(accountID: String, entityID: String, kind: String, method: String, endpoint: String, payload: Data, baseRevision: Int?) {
        operationID = UUID().uuidString
        self.accountID = accountID
        self.entityID = entityID
        self.kind = kind
        self.method = method
        self.endpoint = endpoint
        self.payload = payload
        self.baseRevision = baseRevision
        payloadVersion = 1
        createdAt = Date()
        attempts = 0
        state = "pending"
    }
}

@Model
final class CachedAPIResponse {
    @Attribute(.unique) var key: String
    var accountID: String
    var path: String
    var payload: Data
    var updatedAt: Date
    init(accountID: String, path: String, payload: Data) {
        key = "\(accountID):\(path)"
        self.accountID = accountID
        self.path = path
        self.payload = payload
        updatedAt = Date()
    }
}

@Model
final class SyncCheckpoint {
    @Attribute(.unique) var accountID: String
    var cursor: Int
    init(accountID: String) { self.accountID = accountID; cursor = 0 }
}

enum ExerlySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CachedFoodItem.self, DailyFoodLog.self, Measurement.self, ProgressPhoto.self, Achievement.self, OfflineAction.self]
    }
}
enum ExerlySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        ExerlySchemaV1.models + [SyncedResource.self, PendingMutation.self, CachedAPIResponse.self, SyncCheckpoint.self]
    }

    // Freeze the previous schema, including the field whose name conflicts with
    // Core Data's object-deletion accessor. Only migration uses this model.
    @Model
    final class SyncedResource {
        @Attribute(.unique) var key: String
        var accountID: String
        var kind: String
        var entityID: String
        var serverID: String?
        var revision: Int
        var payload: Data
        var syncedPayload: Data?
        var syncState: String
        var deleted: Bool
        var updatedAt: Date
        init(accountID: String, kind: String, entityID: String, payload: Data) {
            self.key = "\(accountID):\(kind):\(entityID)"
            self.accountID = accountID
            self.kind = kind
            self.entityID = entityID
            self.payload = payload
            revision = 0
            syncState = "pending"
            deleted = false
            updatedAt = Date()
        }
    }
}
enum ExerlySchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        ExerlySchemaV1.models + [SyncedResource.self, PendingMutation.self, CachedAPIResponse.self, SyncCheckpoint.self]
    }
}
enum ExerlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ExerlySchemaV1.self, ExerlySchemaV2.self, ExerlySchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: ExerlySchemaV1.self, toVersion: ExerlySchemaV2.self),
            .custom(fromVersion: ExerlySchemaV2.self, toVersion: ExerlySchemaV3.self, willMigrate: nil, didMigrate: { context in
                let queue = try context.fetch(FetchDescriptor<PendingMutation>(sortBy: [SortDescriptor(\.createdAt)]))
                for resource in try context.fetch(FetchDescriptor<SyncedResource>()) {
                    // The old Boolean was not reliable after a save. Recover
                    // intent from the immutable queue, then the server snapshot.
                    let pending = queue.last { $0.accountID == resource.accountID && $0.kind == resource.kind && $0.entityID == resource.entityID }
                    let payload = try JSONSerialization.jsonObject(with: resource.payload) as? [String: Any]
                    resource.tombstoned = pending.map { $0.method == "DELETE" }
                        ?? (resource.syncState == "discarded" || payload?["deleted_at"] is String)
                }
                try context.save()
            }),
        ]
    }
}
