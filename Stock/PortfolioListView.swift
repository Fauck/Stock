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

    @State private var vm = PortfolioListViewModel()

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
            .sheet(isPresented: $vm.showingSellSheet) {
                if let investment = vm.selectedInvestment {
                    SellView(investment: investment)
                }
            }
            .sheet(isPresented: $vm.showingGroupSellSheet) {
                if let group = vm.selectedGroup {
                    GroupSellView(group: group)
                }
            }
            .alert("確認刪除", isPresented: $vm.showingDeleteAlert, presenting: vm.investmentToDelete) { _ in
                Button("刪除", role: .destructive) {
                    withAnimation {
                        vm.deleteConfirmed(context: modelContext)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { investment in
                Text("確定要刪除 \(StockMapping.displayName(for: investment.ticker)) 的買入紀錄嗎？相關的部分賣出紀錄也會一併刪除。")
            }
            .onAppear {
                vm.investments = investments
                vm.fetchAllPrices()
            }
            .onChange(of: investments) { _, newValue in
                vm.investments = newValue
                // 資料更新時重新拉取即時價（含首次 @Query 載入完成時）
                if !newValue.isEmpty && !vm.hasAnyPrice {
                    vm.fetchAllPrices()
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
            VStack(spacing: 10) {
                // 總覽卡片
                totalSummaryCard
                    .padding(.horizontal)

                // 各標的卡片
                ForEach(vm.groups) { group in
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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(AppColor.primary)
                Text("投資總覽")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                // 重新整理即時價
                Button {
                    vm.fetchAllPrices()
                } label: {
                    if vm.isFetchingPrices {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .disabled(vm.isFetchingPrices)
            }

            AppColor.divider.frame(height: 1)

            HStack {
                Text("總投資成本")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", vm.totalCost))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }

            if vm.hasAnyPrice {
                HStack {
                    Text("目前市值")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "$%.0f", vm.totalMarketValue))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }
                HStack {
                    Text("未實現損益")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(vm.totalPL >= 0 ? "+" : "")$\(vm.totalPL, specifier: "%.0f")")
                            .font(.warmSubheadline())
                            .fontWeight(.bold)
                            .foregroundStyle(Color.profitLossColor(vm.totalPL))
                        Text("(\(vm.totalReturnPct >= 0 ? "+" : "")\(vm.totalReturnPct, specifier: "%.1f")%)")
                            .font(.warmCaption())
                            .fontWeight(.medium)
                            .foregroundStyle(Color.profitLossColor(vm.totalPL))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 群組卡片

    private func groupCard(for group: PortfolioGroup) -> some View {
        let isExpanded = vm.isExpanded(group.ticker)
        let currentPrice = vm.currentPrice(for: group.ticker)

        return VStack(alignment: .leading, spacing: 0) {
            // ── 摘要列（始終顯示）──
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    vm.toggleExpanded(group.ticker)
                }
            } label: {
                HStack(spacing: 12) {
                    // 左：中文名稱（主）+ 代號（副）
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.displayName(for: group.ticker))
                            .font(.warmHeadline())
                            .foregroundStyle(AppColor.primary)
                        Text(group.ticker)
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(minWidth: 60, alignment: .leading)

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

                    // 右：即時價 + 損益
                    if let price = currentPrice {
                        let pl = group.unrealizedProfitLoss(currentPrice: price)
                        let pct = group.returnPercentage(currentPrice: price)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "$%.2f", price))
                                .font(.warmCaption())
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textMain)
                            Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f") (\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%)")
                                .font(.warmCaption2())
                                .foregroundStyle(Color.profitLossColor(pl))
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "$%.0f", group.totalInvested))
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .foregroundStyle(AppColor.textMain)
                            Text("無即時價")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                        }
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

                    // 即時價格 & 損益區塊
                    if let price = currentPrice {
                        let pl = group.unrealizedProfitLoss(currentPrice: price)
                        let pct = group.returnPercentage(currentPrice: price)
                        let marketValue = price * group.totalQuantity

                        VStack(spacing: 8) {
                            // 即時價格列
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.secondary)
                                    Text("即時價")
                                        .font(.warmCaption())
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                                Spacer()
                                Text(String(format: "$%.2f", price))
                                    .font(.warmHeadline())
                                    .foregroundStyle(AppColor.textMain)
                            }

                            // 市值 & 損益列
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("市值")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "$%.0f", marketValue))
                                        .font(.warmCaption())
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColor.textMain)
                                }
                                Spacer()
                                VStack(alignment: .center, spacing: 2) {
                                    Text("成本")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "$%.0f", group.totalInvested))
                                        .font(.warmCaption())
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColor.textMain)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("未實現損益")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f") (\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%)")
                                        .font(.warmCaption())
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.profitLossColor(pl))
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.profitLossColor(pl).opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 14)
                    }

                    // 資訊徽章列
                    HStack {
                        WarmInfoBadge(title: "均價", value: String(format: "$%.2f", group.weightedAverageCost))
                        Spacer()
                        WarmInfoBadge(title: "筆數", value: "\(group.investments.count) 筆")
                        Spacer()
                        WarmInfoBadge(title: "持有", value: "\(group.holdingDays) 天")
                    }
                    .padding(.horizontal, 14)

                    // 現價手動修正 & 整批賣出
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                        Text("現價")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                        TextField(
                            "手動輸入",
                            text: Binding(
                                get: { vm.priceBinding(for: group.ticker) },
                                set: { vm.setPrice($0, for: group.ticker) }
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
                            vm.selectGroupForSell(group)
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
                            detailRow(for: investment, currentPrice: currentPrice)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        vm.confirmDelete(investment)
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

    private func detailRow(for investment: Investment, currentPrice: Double?) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vm.formattedDate(investment.buyDate))
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        Text("\(investment.holdingDays) 天")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
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
                // 右側：單筆損益 + 賣出按鈕
                VStack(alignment: .trailing, spacing: 4) {
                    if let price = currentPrice {
                        let pl = investment.unrealizedProfitLoss(currentPrice: price)
                        let pct = investment.returnPercentage(currentPrice: price)
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmCaption2())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                        Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%")
                            .font(.warmCaption2())
                            .foregroundStyle(Color.profitLossColor(pct))
                    }
                    Button {
                        vm.selectForSell(investment)
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
            }
        }
        .padding(10)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    PortfolioListView()
        .modelContainer(for: Investment.self, inMemory: true)
}
