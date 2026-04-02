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

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showingAddSheet = false

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - 月份切換卡片
                        calendarCard

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
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddInvestmentView(selectedDate: selectedDate)
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

    // MARK: - 月份切換標頭
    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.primary)
            }

            Spacer()

            Text(monthYearString(from: currentMonth))
                .font(.warmTitle())
                .foregroundStyle(AppColor.textMain)

            Spacer()

            Button {
                changeMonth(by: 1)
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
            ForEach(weekdaySymbols, id: \.self) { symbol in
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
        let days = generateDaysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Text("")
                        .frame(height: 42)
                }
            }
        }
    }

    // MARK: - 單日格子（日誌風格）
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasBuy = !buyRecordsOnDate(date).isEmpty
        let hasSell = !sellRecordsOnDate(date).isEmpty

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.callout, design: .rounded, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? AppColor.primary : AppColor.textMain))

                // 買入 / 賣出圓點指示器
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
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppColor.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isToday && !isSelected ? AppColor.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 選擇日期的紀錄列表
    private var selectedDateRecords: some View {
        let buyRecords = buyRecordsOnDate(selectedDate)
        let sellRecords = sellRecordsOnDate(selectedDate)
        let hasAnyRecord = !buyRecords.isEmpty || !sellRecords.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle")
                    .foregroundStyle(AppColor.primary)
                Text(dateString(from: selectedDate))
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Button {
                    showingAddSheet = true
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.ticker)
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Text(String(format: "買入價：$%.2f", investment.buyPrice))
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
            Text(String(format: "%.0f 股", investment.originalQuantity))
                .font(.warmSubheadline())
                .foregroundStyle(AppColor.primary)
        }
        .padding(12)
        .background(AppColor.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 賣出紀錄列
    private func sellRow(_ investment: Investment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.ticker)
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
                let pl = investment.realizedProfitLoss
                Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                    .font(.warmCaption())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.profitLossColor(pl))
            }
        }
        .padding(12)
        .background(AppColor.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helper Methods

    /// 該日期的買入紀錄
    private func buyRecordsOnDate(_ date: Date) -> [Investment] {
        investments.filter { calendar.isDate($0.buyDate, inSameDayAs: date) }
    }

    /// 該日期的賣出紀錄（從所有已平倉紀錄中篩選，包含部分賣出拆分紀錄）
    private func sellRecordsOnDate(_ date: Date) -> [Investment] {
        closedInvestments.filter { inv in
            guard let sellDate = inv.sellDate else { return false }
            return calendar.isDate(sellDate, inSameDayAs: date)
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func generateDaysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingSpaces = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M 月 d 日（EEEE）"
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: Investment.self, inMemory: true)
}
