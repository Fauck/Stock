//
//  TransactionHistoryView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 買入紀錄流水帳：日誌風格卡片，支援日期區間篩選
struct TransactionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Investment> { !$0.isPartialSellRecord },
           sort: \Investment.buyDate, order: .reverse)
    private var allInvestments: [Investment]

    @State private var selectedFilter: DateFilterOption = .all
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var investmentToDelete: Investment?
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 日期篩選器
                    filterBar

                    if filteredInvestments.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        transactionList
                    }
                }
            }
            .navigationTitle("交易紀錄")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("確認刪除", isPresented: $showingDeleteAlert, presenting: investmentToDelete) { investment in
                Button("刪除", role: .destructive) {
                    withAnimation {
                        Investment.deleteInvestment(investment, context: modelContext)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { investment in
                Text("確定要刪除 \(investment.ticker) 的買入紀錄嗎？相關的部分賣出紀錄也會一併刪除。")
            }
        }
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.primary.opacity(0.3))
            Text("無買入紀錄")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Text("在選定的時間區間內沒有買入紀錄")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 篩選後的紀錄

    private var filteredInvestments: [Investment] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedFilter {
        case .all:
            return allInvestments
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                return allInvestments
            }
            return allInvestments.filter { $0.buyDate >= weekAgo }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
                return allInvestments
            }
            return allInvestments.filter { $0.buyDate >= monthAgo }
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let firstDayOfMonth = calendar.date(from: components),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth) else {
                return allInvestments
            }
            return allInvestments.filter { $0.buyDate >= firstDayOfMonth && $0.buyDate < nextMonth }
        case .custom:
            let startOfDay = calendar.startOfDay(for: customStartDate)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) else {
                return allInvestments
            }
            return allInvestments.filter { $0.buyDate >= startOfDay && $0.buyDate < endOfDay }
        }
    }

    // MARK: - 日期篩選列

    private var filterBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilterOption.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedFilter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    selectedFilter == option
                                        ? AppColor.primary
                                        : AppColor.cardBackground
                                )
                                .foregroundStyle(
                                    selectedFilter == option
                                        ? .white
                                        : AppColor.textMain
                                )
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            if selectedFilter == .custom {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("起始日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $customEndDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 8)
        .background(AppColor.cardBackground)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - 交易列表

    private var transactionList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 總覽
                summaryCard
                    .padding(.horizontal, 16)

                // 逐筆紀錄
                ForEach(filteredInvestments) { investment in
                    transactionCard(for: investment)
                        .contextMenu {
                            Button(role: .destructive) {
                                investmentToDelete = investment
                                showingDeleteAlert = true
                            } label: {
                                Label("刪除紀錄", systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - 總覽卡片

    private var summaryCard: some View {
        let records = filteredInvestments
        let totalCost = records.reduce(0.0) { $0 + $1.originalTotalCost }

        return HStack {
            Image(systemName: "book.fill")
                .foregroundStyle(AppColor.primary)
            Text("共 \(records.count) 筆買入紀錄")
                .font(.warmSubheadline())
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Text(String(format: "總投入 $%.0f", totalCost))
                .font(.warmSubheadline())
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.primary)
        }
        .cardStyle()
    }

    // MARK: - 單筆交易卡片

    private func transactionCard(for investment: Investment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一列：標的 + 狀態 + 日期
            HStack {
                Text(investment.ticker)
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                statusBadge(for: investment)
                Text(formattedDate(investment.buyDate))
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 第二列：資訊徽章
            HStack {
                WarmInfoBadge(title: "買入價", value: String(format: "$%.2f", investment.buyPrice))
                Spacer()
                WarmInfoBadge(title: "買入數量", value: String(format: "%.0f 股", investment.originalQuantity))
                Spacer()
                WarmInfoBadge(title: "買入成本", value: String(format: "$%.0f", investment.originalTotalCost))
            }

            // 第三列：已平倉資訊
            if investment.isClosed {
                AppColor.divider.frame(height: 1)
                HStack {
                    if let sp = investment.sellPrice {
                        WarmInfoBadge(title: "賣出價", value: String(format: "$%.2f", sp))
                    }
                    Spacer()
                    if let sq = investment.sellQuantity {
                        WarmInfoBadge(title: "賣出量", value: String(format: "%.0f 股", sq))
                    }
                    Spacer()
                    let pl = investment.realizedProfitLoss
                    VStack(spacing: 2) {
                        Text("損益")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.profitLossColor(pl).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else if investment.quantity < investment.originalQuantity {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.softUp)
                    Text(String(format: "已賣出 %.0f 股，剩餘 %.0f 股",
                                investment.originalQuantity - investment.quantity,
                                investment.quantity))
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(8)
                .background(AppColor.softUp.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // 買入理由
            if !investment.buyReason.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                    Text(investment.buyReason)
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.top, 2)
            }

            // 賣出理由
            if !investment.sellReason.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.softUp.opacity(0.6))
                    Text(investment.sellReason)
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 狀態標籤

    private func statusBadge(for investment: Investment) -> some View {
        let color: Color = {
            if investment.isClosed {
                return AppColor.textSecondary
            } else if investment.quantity < investment.originalQuantity {
                return AppColor.softUp
            } else {
                return AppColor.secondary
            }
        }()
        return WarmStatusBadge(text: investment.statusText, color: color)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy/MM/dd（EE）"
        return formatter.string(from: date)
    }
}

#Preview {
    TransactionHistoryView()
        .modelContainer(for: Investment.self, inMemory: true)
}
