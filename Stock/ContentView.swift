//
//  ContentView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 主視圖：使用 TabView 整合四個主要頁面，溫暖日誌風格
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("行事曆", systemImage: "calendar.badge.plus")
                }
                .tag(0)

            PortfolioListView()
                .tabItem {
                    Label("持有庫存", systemImage: "leaf.fill")
                }
                .tag(1)

            TransactionHistoryView()
                .tabItem {
                    Label("交易紀錄", systemImage: "book.closed.fill")
                }
                .tag(2)

            SoldRecordsView()
                .tabItem {
                    Label("已實現損益", systemImage: "checkmark.seal.fill")
                }
                .tag(3)
        }
        .tint(AppColor.primary)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Investment.self, inMemory: true)
}
