//
//  StockSchemaVersioning.swift
//  Stock
//
//  SwiftData VersionedSchema 與 SchemaMigrationPlan
//  V1：鎖定目前的 Investment + TradeJournal schema
//

import Foundation
import SwiftData

// MARK: - V1 Schema（目前版本）

enum StockSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Investment.self, TradeJournal.self]
    }
}

// MARK: - Migration Plan

enum StockMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StockSchemaV1.self]
    }

    /// 目前只有 V1，無需任何 migration stage
    static var stages: [MigrationStage] {
        []
    }
}
