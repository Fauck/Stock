//
//  StockApp.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

@main
struct StockApp: App {
    /// 標記是否退回記憶體模式（持久化儲存失敗時）
    static var isRunningInMemoryFallback = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: StockSchemaV1.self)
        let persistentConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: StockMigrationPlan.self,
                configurations: [persistentConfig]
            )
        } catch {
            #if DEBUG
            print("[StockApp] 持久化 ModelContainer 建立失敗，退回記憶體模式: \(error)")
            #endif
            StockApp.isRunningInMemoryFallback = true
            let inMemoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [inMemoryConfig]
                )
            } catch {
                fatalError("無法建立 ModelContainer（含記憶體備援）: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
