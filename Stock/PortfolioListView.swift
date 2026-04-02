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

    // 單筆賣出
    @State private var selectedInvestment: Investment?
    @State private var showingSellSheet = false

    // 整批賣出
    @State private var selectedGroup: PortfolioGroup?
    @State private var showingGroupSellSheet = false

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
            VStack(spacing: 16) {
                // 總覽卡片
                totalSummaryCard
                    .padding(.horizontal)

                // 各標的卡片
                ForEach(groups) { group in
                    groupCard(for: group)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            // 標題列
            HStack {
                Text(group.ticker)
                    .font(.warmTitle())
                    .foregroundStyle(AppColor.primary)
                Spacer()
                Text(String(format: "%.0f 股", group.totalQuantity))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 資訊徽章列
            HStack(spacing: 8) {
                WarmInfoBadge(title: "均價", value: String(format: "$%.2f", group.weightedAverageCost))
                Spacer()
                WarmInfoBadge(title: "總投入", value: String(format: "$%.0f", group.totalInvested))
                Spacer()
                if let priceStr = currentPrices[group.ticker],
                   let price = Double(priceStr), price > 0 {
                    let pl = group.unrealizedProfitLoss(currentPrice: price)
                    let pct = group.returnPercentage(currentPrice: price)
                    VStack(spacing: 2) {
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                        Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                            .font(.warmCaption2())
                            .foregroundStyle(Color.profitLossColor(pct))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    WarmInfoBadge(title: "筆數", value: "\(group.investments.count) 筆")
                }
            }

            AppColor.divider.frame(height: 1)

            // 現價輸入
            HStack(spacing: 12) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                Text("目前股價")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                TextField(
                    "輸入現價",
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
                .frame(maxWidth: 120)
                Spacer()
            }

            // 整批賣出按鈕
            Button {
                selectedGroup = group
                showingGroupSellSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("整批賣出 \(group.ticker)")
                        .fontWeight(.medium)
                }
                .font(.warmCaption())
                .foregroundStyle(AppColor.softUp)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppColor.softUp.opacity(0.12))
                .clipShape(Capsule())
            }

            // 展開明細
            DisclosureGroup {
                ForEach(group.investments) { investment in
                    detailRow(for: investment)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.warmCaption2())
                    Text("買入明細（\(group.investments.count) 筆）")
                        .font(.warmCaption())
                }
                .foregroundStyle(AppColor.primary)
            }
            .tint(AppColor.primary)
        }
        .cardStyle()
    }

    // MARK: - 展開後的單筆紀錄

    private func detailRow(for investment: Investment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(formattedDate(investment.buyDate))
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                    HStack(spacing: 10) {
                        Text(String(format: "買入價 $%.2f", investment.buyPrice))
                            .font(.warmCaption())
                        Text(String(format: "%.0f 股", investment.quantity))
                            .font(.warmCaption())
                        Text(String(format: "成本 $%.0f", investment.totalCost))
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

            if !investment.buyReason.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "text.quote")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                    Text(investment.buyReason)
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(AppColor.background.opacity(0.4))
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
