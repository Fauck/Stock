//
//  SoldRecordsView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

// MARK: - 已賣出紀錄頁面（日誌風格）

struct SoldRecordsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Investment> { $0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var allSoldInvestments: [Investment]

    @State private var vm = SoldRecordsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar

                    if vm.filteredInvestments.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        recordsList
                    }
                }
            }
            .navigationTitle("已實現損益")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("確認刪除", isPresented: $vm.showingDeleteAlert, presenting: vm.investmentToDelete) { _ in
                Button("刪除", role: .destructive) {
                    withAnimation {
                        vm.deleteConfirmed(context: modelContext)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { investment in
                if investment.isPartialSellRecord {
                    Text("確定要刪除 \(investment.ticker) 的賣出紀錄嗎？賣出數量將歸還至原始買入紀錄。")
                } else {
                    Text("確定要刪除 \(investment.ticker) 的已平倉紀錄嗎？")
                }
            }
            .onAppear {
                vm.allSoldInvestments = allSoldInvestments
            }
            .onChange(of: allSoldInvestments) { _, newValue in
                vm.allSoldInvestments = newValue
            }
        }
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.primary.opacity(0.3))
            Text("無賣出紀錄")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Text("在選定的時間區間內沒有已平倉的交易紀錄")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
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
                                vm.selectedFilter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    vm.selectedFilter == option
                                        ? AppColor.primary
                                        : AppColor.cardBackground
                                )
                                .foregroundStyle(
                                    vm.selectedFilter == option
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

            if vm.selectedFilter == .custom {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("起始日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $vm.customStartDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $vm.customEndDate, displayedComponents: .date)
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

    // MARK: - 紀錄列表

    private var recordsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 損益總覽
                profitLossSummaryCard
                    .padding(.horizontal, 16)

                // 個別紀錄
                ForEach(vm.filteredInvestments) { investment in
                    soldRecordCard(for: investment)
                        .contextMenu {
                            Button(role: .destructive) {
                                vm.confirmDelete(investment)
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

    // MARK: - 損益總覽卡片

    private var profitLossSummaryCard: some View {
        VStack(spacing: 12) {
            // 總損益（最醒目）
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總已實現損益")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text("\(vm.totalPL >= 0 ? "+" : "")$\(vm.totalPL, specifier: "%.0f")")
                        .font(.warmLargeNumber())
                        .foregroundStyle(Color.profitLossColor(vm.totalPL))
                }
                Spacer()
                Image(systemName: vm.totalPL >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.profitLossColor(vm.totalPL).opacity(0.3))
            }

            AppColor.divider.frame(height: 1)

            HStack {
                Text("總賣出金額")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", vm.totalSellAmount))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }
            HStack {
                Text("總成本金額")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", vm.totalCostAmount))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }
            HStack {
                Text("交易筆數")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("\(vm.recordCount) 筆")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }
        }
        .cardStyle()
    }

    // MARK: - 單筆已賣出紀錄卡片

    private func soldRecordCard(for investment: Investment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標的名稱 + 賣出日期
            HStack {
                Text(investment.ticker)
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                if let sellDate = investment.sellDate {
                    Text(vm.formattedDate(sellDate))
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            // 買賣資訊
            HStack {
                WarmInfoBadge(title: "買入價", value: String(format: "$%.2f", investment.buyPrice))
                Spacer()
                if let sp = investment.sellPrice {
                    WarmInfoBadge(title: "賣出價", value: String(format: "$%.2f", sp))
                }
                Spacer()
                if let sq = investment.sellQuantity {
                    WarmInfoBadge(title: "數量", value: String(format: "%.0f 股", sq))
                }
            }

            // 損益顯示
            AppColor.divider.frame(height: 1)

            HStack {
                let pl = investment.realizedProfitLoss
                let pct = investment.realizedReturnPercentage
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                        .font(.warmSubheadline())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.profitLossColor(pl))
                    Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                        .font(.warmCaption())
                        .foregroundStyle(Color.profitLossColor(pct))
                }
            }
        }
        .cardStyle()
    }
}

#Preview {
    SoldRecordsView()
        .modelContainer(for: Investment.self, inMemory: true)
}
