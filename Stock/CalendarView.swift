//
//  CalendarView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 行事曆視圖：日誌風格月曆，使用者可點擊日期新增買入紀錄
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    /// 所有非系統拆分的投資紀錄（包含已平倉），用於在行事曆上標記買入日期
    @Query(filter: #Predicate<Investment> { !$0.isPartialSellRecord },
           sort: \Investment.buyDate, order: .reverse)
    private var investments: [Investment]

    /// 所有已平倉紀錄（包含部分賣出拆分），用於在行事曆上標記賣出日期
    @Query(filter: #Predicate<Investment> { $0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var closedInvestments: [Investment]

    /// 交易日誌
    @Query private var allJournals: [TradeJournal]

    @State private var vm = CalendarViewModel()
    @State private var selectedJournalInvestment: Investment?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - 月份切換卡片
                        calendarCard

                        // MARK: - 月度統計摘要
                        if vm.hasTradesInMonth {
                            monthSummaryCard
                        }

                        // MARK: - 選擇日期的買入紀錄
                        selectedDateRecords
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("投資日誌")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $vm.showingAddSheet) {
                AddInvestmentView(selectedDate: vm.selectedDate)
            }
            .onAppear {
                vm.investments = investments
                vm.closedInvestments = closedInvestments
                vm.journals = allJournals
            }
            .onChange(of: investments) { _, newValue in
                vm.investments = newValue
            }
            .onChange(of: closedInvestments) { _, newValue in
                vm.closedInvestments = newValue
            }
            .onChange(of: allJournals) { _, newValue in
                vm.journals = newValue
            }
            .sheet(item: $selectedJournalInvestment) { investment in
                if let journal = vm.journal(for: investment.id) {
                    NavigationStack {
                        TradeJournalDetailView(investment: investment, journal: journal)
                    }
                }
            }
            .sheet(item: $vm.daySummary) { summary in
                daySummarySheet(summary)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 日曆卡片

    private var calendarCard: some View {
        VStack(spacing: 12) {
            // 月份切換
            monthHeader

            // 星期標頭
            weekdayHeader

            // 日期格子
            daysGrid
        }
        .padding(.horizontal)
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - 月度統計摘要

    private var monthSummaryCard: some View {
        let s = vm.currentMonthSummary
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("本月交易摘要")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 第一行：買入 / 賣出 / 勝率
            HStack(spacing: 0) {
                summaryItem(label: "買入", value: "\(s.buyCount) 筆", color: AppColor.softUp)
                summaryItem(label: "賣出", value: "\(s.sellCount) 筆", color: AppColor.softDown)
                if s.sellCount > 0 {
                    summaryItem(label: "勝率", value: String(format: "%.0f%%", s.winRate),
                                color: s.winRate >= 50 ? AppColor.softUp : AppColor.softDown)
                }
            }

            // 第二行：投入金額 / 已實現損益
            HStack(spacing: 0) {
                if s.totalInvested > 0 {
                    summaryItem(label: "投入", value: formatAmount(s.totalInvested), color: AppColor.textMain)
                }
                if s.sellCount > 0 {
                    summaryItem(label: "已實現",
                                value: "\(s.realizedPnL >= 0 ? "+" : "")$\(formatAmount(abs(s.realizedPnL)))",
                                color: Color.profitLossColor(s.realizedPnL))
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.warmTertiary())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatAmount(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.1f萬", value / 10000)
        }
        return String(format: "$%.0f", value)
    }

    // MARK: - 月份切換標頭
    private var monthHeader: some View {
        HStack {
            Button {
                vm.changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.primary)
            }

            Spacer()

            Text(vm.monthYearString(from: vm.currentMonth))
                .font(.warmTitle())
                .foregroundStyle(AppColor.textMain)

            Spacer()

            Button {
                vm.changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.primary)
            }
        }
    }

    // MARK: - 星期標頭
    private var weekdayHeader: some View {
        HStack {
            ForEach(vm.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.warmCaption2())
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 日期格子
    private var daysGrid: some View {
        let days = vm.generateDaysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Text("")
                        .frame(height: 54)
                }
            }
        }
    }

    // MARK: - 單日格子（日誌風格）
    private func dayCell(for date: Date) -> some View {
        let isSelected = vm.isDateInSameDay(date, vm.selectedDate)
        let isToday = vm.isDateToday(date)
        let hasBuy = !vm.buyRecordsOnDate(date).isEmpty
        let hasSell = !vm.sellRecordsOnDate(date).isEmpty
        let pnl = vm.realizedPnLOnDate(date)

        return Button {
            vm.handleDayTap(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(vm.dayComponent(from: date))")
                    .font(.system(.callout, design: .rounded, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? AppColor.primary : AppColor.textMain))

                // 有已實現損益 → 顯示金額；否則顯示圓點指示器
                if let pnl {
                    Text(formatCellAmount(pnl))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.profitLossColor(pnl))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    HStack(spacing: 3) {
                        if hasBuy {
                            Circle()
                                .fill(isSelected ? .white.opacity(0.8) : AppColor.softUp)
                                .frame(width: 5, height: 5)
                        }
                        if hasSell {
                            Circle()
                                .fill(isSelected ? .white.opacity(0.8) : AppColor.softDown)
                                .frame(width: 5, height: 5)
                        }
                        if !hasBuy && !hasSell {
                            Color.clear.frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                    .fill(isSelected ? AppColor.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                    .stroke(isToday && !isSelected ? AppColor.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// 日格內損益金額格式化（無條件捨去）
    private func formatCellAmount(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        let abs = abs(value)
        if abs >= 10000 {
            let truncated = floor(abs / 1000) / 10  // 無條件捨去到小數一位
            return "\(sign)\(String(format: "%.1f", truncated))萬"
        }
        return "\(sign)\(Int(floor(abs)))"
    }

    // MARK: - 選擇日期的紀錄列表
    private var selectedDateRecords: some View {
        let buyRecords = vm.buyRecordsOnDate(vm.selectedDate)
        let sellRecords = vm.sellRecordsOnDate(vm.selectedDate)
        let hasAnyRecord = !buyRecords.isEmpty || !sellRecords.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle")
                    .foregroundStyle(AppColor.primary)
                Text(vm.dateString(from: vm.selectedDate))
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Button {
                    vm.showingAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("新增買入")
                    }
                    .font(.warmCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppColor.primary)
                    .clipShape(Capsule())
                }
            }

            if !hasAnyRecord {
                VStack(spacing: 8) {
                    Image(systemName: "pencil.slash")
                        .font(.title2)
                        .foregroundStyle(AppColor.textSecondary.opacity(0.4))
                    Text("此日期尚無交易紀錄")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // 買入紀錄
                if !buyRecords.isEmpty {
                    sectionHeader(title: "買入", icon: "arrow.down.circle.fill", color: AppColor.softUp)
                    ForEach(buyRecords) { investment in
                        buyRow(investment)
                    }
                }

                // 賣出紀錄
                if !sellRecords.isEmpty {
                    if !buyRecords.isEmpty {
                        AppColor.divider.frame(height: 1)
                    }
                    sectionHeader(title: "賣出", icon: "arrow.up.circle.fill", color: AppColor.softDown)
                    ForEach(sellRecords) { investment in
                        sellRow(investment)
                    }
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - 區段標頭
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.warmCaption())
                .foregroundStyle(color)
            Text(title)
                .font(.warmCaption())
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    // MARK: - 買入紀錄列
    private func buyRow(_ investment: Investment) -> some View {
        let journal = vm.journal(for: investment.id)
        let hasJournal = journal != nil

        return Button {
            if hasJournal { selectedJournalInvestment = investment }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(StockMapping.displayName(for: investment.ticker))
                            .font(.warmHeadline())
                            .foregroundStyle(AppColor.textMain)
                        Text(String(format: "買入價：$%.2f", investment.buyPrice))
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f 股", investment.originalQuantity))
                            .font(.warmSubheadline())
                            .foregroundStyle(AppColor.primary)
                        if let score = journal?.emotionScore {
                            emotionBadge(score: score)
                        }
                    }
                }

                // 進場理由摘要
                if let journal, !journal.setup.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColor.textSecondary)
                        Text(journal.setup.prefix(30) + (journal.setup.count > 30 ? "..." : ""))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                    }
                }

                // 有日誌提示
                if hasJournal {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                        Text("查看日誌")
                            .font(.warmTertiary())
                    }
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                }
            }
            .padding(12)
            .background(AppColor.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 賣出紀錄列
    private func sellRow(_ investment: Investment) -> some View {
        let journal = vm.journal(for: investment.id)
        let hasJournal = journal != nil

        return Button {
            if hasJournal { selectedJournalInvestment = investment }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(StockMapping.displayName(for: investment.ticker))
                            .font(.warmHeadline())
                            .foregroundStyle(AppColor.textMain)
                        if let sp = investment.sellPrice {
                            Text(String(format: "賣出價：$%.2f", sp))
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let sq = investment.sellQuantity {
                            Text(String(format: "%.0f 股", sq))
                                .font(.warmSubheadline())
                                .foregroundStyle(AppColor.softDown)
                        }
                        let pl = investment.realizedProfitLoss()
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                    }
                }

                // R-Multiple + 出場理由
                if let journal {
                    HStack(spacing: 8) {
                        if let r = journal.rMultiple {
                            Text(String(format: "%+.2fR", r))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.rMultipleColor(r))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.rMultipleColor(r).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if !journal.exitReason.isEmpty {
                            Text(journal.exitReason.prefix(20) + (journal.exitReason.count > 20 ? "..." : ""))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(AppColor.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }

                // 有日誌提示
                if hasJournal {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                        Text("查看日誌")
                            .font(.warmTertiary())
                    }
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                }
            }
            .padding(12)
            .background(AppColor.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日摘要彈窗

    private func daySummarySheet(_ summary: CalendarViewModel.DaySummary) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 統計摘要
                    HStack(spacing: 0) {
                        if summary.buyCount > 0 {
                            summaryItem(label: "買入", value: "\(summary.buyCount) 筆", color: AppColor.softUp)
                        }
                        if summary.sellCount > 0 {
                            summaryItem(label: "賣出", value: "\(summary.sellCount) 筆", color: AppColor.softDown)
                        }
                        if let pnl = summary.totalPnL {
                            summaryItem(
                                label: "已實現",
                                value: "\(pnl >= 0 ? "+" : "")$\(formatAmount(abs(pnl)))",
                                color: Color.profitLossColor(pnl)
                            )
                        }
                    }
                    .cardStyle()

                    // 逐筆明細
                    VStack(spacing: 8) {
                        ForEach(summary.items) { item in
                            daySummaryRow(item)
                        }
                    }
                    .cardStyle()
                }
                .padding(.vertical, 8)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle(vm.dateString(from: summary.date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("關閉") { vm.daySummary = nil }
                }
            }
        }
    }

    private func daySummaryRow(_ item: CalendarViewModel.DaySummaryItem) -> some View {
        HStack {
            // 買/賣標籤
            Text(item.type == .buy ? "買" : "賣")
                .font(.warmCaption2())
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(item.type == .buy ? AppColor.softUp : AppColor.softDown)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
                Text(String(format: "%.0f 股 × $%.2f", item.quantity, item.price))
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            if let pnl = item.pnl {
                Text("\(pnl >= 0 ? "+" : "")$\(String(format: "%.0f", pnl))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.profitLossColor(pnl))
            } else {
                Text(String(format: "$%.0f", item.price * item.quantity))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 情緒分數 Badge

    private func emotionBadge(score: Int) -> some View {
        let emoji: String = switch score {
        case 1: "😨"
        case 2: "😟"
        case 3: "😐"
        case 4: "😊"
        case 5: "🤑"
        default: "😐"
        }
        let color: Color = switch score {
        case 1, 2: AppColor.softDown
        case 4, 5: AppColor.softUp
        default: AppColor.textSecondary
        }
        return Text("\(emoji)\(score)")
            .font(.warmTertiary())
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
