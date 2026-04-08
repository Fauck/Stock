//
//  PortfolioListView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 庫存列表視圖：卡片式設計，溫暖日誌風格
struct PortfolioListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Investment> { !$0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var investments: [Investment]

    /// 以 ticker 為 key 儲存使用者輸入的目前價格
    @State private var currentPrices: [String: String] = [:]

    /// 目前展開的群組 ticker
    @State private var expandedTicker: String?

    // 單筆賣出
    @State private var selectedInvestment: Investment?
    @State private var showingSellSheet = false

    // 整批賣出
    @State private var selectedGroup: PortfolioGroup?
    @State private var showingGroupSellSheet = false

    // 刪除
    @State private var investmentToDelete: Investment?
    @State private var showingDeleteAlert = false

    /// 將查詢結果群組化
    private var groups: [PortfolioGroup] {
        PortfolioGroup.buildGroups(from: investments)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                Group {
                    if investments.isEmpty {
                        emptyState
                    } else {
                        portfolioList
                    }
                }
            }
            .navigationTitle("持有庫存")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingSellSheet) {
                if let investment = selectedInvestment {
                    SellView(investment: investment)
                }
            }
            .sheet(isPresented: $showingGroupSellSheet) {
                if let group = selectedGroup {
                    GroupSellView(group: group)
                }
            }
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
        VStack(spacing: 16) {
            Image(systemName: "leaf")
                .font(.system(size: 50))
                .foregroundStyle(AppColor.primary.opacity(0.4))
            Text("尚無持有部位")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Text("請前往行事曆頁面新增買入紀錄")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 庫存列表

    private var portfolioList: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 總覽卡片
                totalSummaryCard
                    .padding(.horizontal)

                // 各標的卡片
                ForEach(groups) { group in
                    groupCard(for: group)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .keyboardDismissable()
    }

    // MARK: - 總覽卡片

    private var totalSummaryCard: some View {
        let totalCost = investments.reduce(0.0) { $0 + $1.totalCost }
        let totalMarketValue = groups.reduce(0.0) { sum, group in
            guard let priceStr = currentPrices[group.ticker],
                  let price = Double(priceStr), price > 0 else { return sum }
            return sum + price * group.totalQuantity
        }
        let hasAnyPrice = groups.contains { group in
            guard let priceStr = currentPrices[group.ticker],
                  let price = Double(priceStr) else { return false }
            return price > 0
        }
        let totalPL = totalMarketValue - totalCost

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(AppColor.primary)
                Text("投資總覽")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
            }

            AppColor.divider.frame(height: 1)

            HStack {
                Text("總投資成本")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", totalCost))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }

            if hasAnyPrice {
                HStack {
                    Text("目前市值")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "$%.0f", totalMarketValue))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }
                HStack {
                    Text("未實現損益")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text("\(totalPL >= 0 ? "+" : "")$\(totalPL, specifier: "%.0f")")
                        .font(.warmSubheadline())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.profitLossColor(totalPL))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 群組卡片

    private func groupCard(for group: PortfolioGroup) -> some View {
        let isExpanded = expandedTicker == group.ticker
        let currentPrice: Double? = {
            guard let str = currentPrices[group.ticker], let p = Double(str), p > 0 else { return nil }
            return p
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // ── 摘要列（始終顯示）──
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    expandedTicker = isExpanded ? nil : group.ticker
                }
            } label: {
                HStack(spacing: 12) {
                    // 左：標的代號
                    Text(group.ticker)
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.primary)
                        .frame(minWidth: 50, alignment: .leading)

                    // 中：股數 + 均價
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f 股", group.totalQuantity))
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textMain)
                        Text(String(format: "均價 $%.2f", group.weightedAverageCost))
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    Spacer()

                    // 右：損益或總投入
                    if let price = currentPrice {
                        let pl = group.unrealizedProfitLoss(currentPrice: price)
                        let pct = group.returnPercentage(currentPrice: price)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                                .font(.warmCaption())
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.profitLossColor(pl))
                            Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%")
                                .font(.warmCaption2())
                                .foregroundStyle(Color.profitLossColor(pct))
                        }
                    } else {
                        Text(String(format: "$%.0f", group.totalInvested))
                            .font(.warmCaption())
                            .fontWeight(.medium)
                            .foregroundStyle(AppColor.textMain)
                    }

                    // 展開指示箭頭
                    Image(systemName: "chevron.right")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── 展開的詳細內容 ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    AppColor.divider.frame(height: 1)
                        .padding(.horizontal, 14)

                    // 資訊徽章列
                    HStack {
                        WarmInfoBadge(title: "均價", value: String(format: "$%.2f", group.weightedAverageCost))
                        Spacer()
                        WarmInfoBadge(title: "總投入", value: String(format: "$%.0f", group.totalInvested))
                        Spacer()
                        WarmInfoBadge(title: "筆數", value: "\(group.investments.count) 筆")
                    }
                    .padding(.horizontal, 14)

                    // 現價輸入
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                        Text("現價")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                        TextField(
                            "輸入",
                            text: Binding(
                                get: { currentPrices[group.ticker] ?? "" },
                                set: { currentPrices[group.ticker] = $0 }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: 100)
                        Spacer()

                        // 整批賣出
                        Button {
                            selectedGroup = group
                            showingGroupSellSheet = true
                        } label: {
                            Text("整批賣出")
                                .font(.warmCaption2())
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(AppColor.softUp)
                                .background(AppColor.softUp.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)

                    // 買入明細
                    VStack(spacing: 6) {
                        ForEach(group.investments) { investment in
                            detailRow(for: investment)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        investmentToDelete = investment
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("刪除紀錄", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    // MARK: - 展開後的單筆紀錄

    private func detailRow(for investment: Investment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate(investment.buyDate))
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary)
                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", investment.buyPrice))
                        .font(.warmCaption())
                    Text("×")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "%.0f 股", investment.quantity))
                        .font(.warmCaption())
                    Text(String(format: "$%.0f", investment.totalCost))
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.primary)
                }
            }
            Spacer()
            Button {
                selectedInvestment = investment
                showingSellSheet = true
            } label: {
                Text("賣出")
                    .font(.warmCaption2())
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColor.softUp.opacity(0.15))
                    .foregroundStyle(AppColor.softUp)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

#Preview {
    PortfolioListView()
        .modelContainer(for: Investment.self, inMemory: true)
}
