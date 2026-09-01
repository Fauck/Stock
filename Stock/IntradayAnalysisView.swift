import SwiftUI

/// 盤中分析頁面：分價量表、成交明細、大單追蹤
struct IntradayAnalysisView: View {
    @State private var vm: IntradayAnalysisViewModel

    init(symbol: String = "") {
        _vm = State(initialValue: IntradayAnalysisViewModel(symbol: symbol))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜尋列
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if vm.isLoading && vm.volumeRows.isEmpty && vm.tradeRows.isEmpty {
                    loadingState
                } else if let error = vm.errorMessage, vm.volumeRows.isEmpty && vm.tradeRows.isEmpty {
                    errorState(error)
                } else if vm.volumeRows.isEmpty && vm.tradeRows.isEmpty && !vm.symbol.isEmpty && vm.lastUpdated != nil {
                    emptyState
                } else if !vm.volumeRows.isEmpty || !vm.tradeRows.isEmpty {
                    // 摘要 + Tab + 內容
                    ScrollView {
                        VStack(spacing: 12) {
                            summaryCard
                            tabBar
                            contentArea
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("盤中分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { vm.load() } label: {
                    if vm.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading || vm.symbol.isEmpty)
            }
        }
        .task {
            if !vm.symbol.isEmpty {
                vm.load()
            }
        }
    }

    // MARK: - 搜尋列

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                TextField("輸入股票代號或名稱", text: $vm.symbol)
                    .font(.warmBody())
                    .submitLabel(.search)
                    .onSubmit { vm.load() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            Button {
                vm.load()
            } label: {
                Text("查詢")
                    .font(.warmCaption())
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColor.primary)
                    .clipShape(Capsule())
            }
            .disabled(vm.symbol.isEmpty || vm.isLoading)
        }
    }

    // MARK: - 摘要卡片

    private var summaryCard: some View {
        VStack(spacing: 10) {
            // 標題列
            HStack {
                if !vm.stockName.isEmpty {
                    Text(vm.stockName)
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.primary)
                }
                Text(vm.resolvedSymbol.isEmpty ? vm.symbol : "")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if let time = vm.lastUpdated {
                    Text("更新 \(time)")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            AppColor.divider.frame(height: 1)

            // 四格摘要
            HStack {
                VStack(spacing: 2) {
                    Text("總量")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(vm.formatVolume(vm.totalVolume))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("外盤")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(vm.formatVolume(vm.totalAsk))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("內盤")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(vm.formatVolume(vm.totalBid))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.softUp)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("外/內比")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                    if let ratio = vm.bidAskRatio {
                        Text(String(format: "%.2f", ratio))
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(ratio >= 1 ? AppColor.secondary : AppColor.softUp)
                    } else {
                        Text("—")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Tab 切換列

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(IntradayTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.warmCaption())
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(vm.selectedTab == tab ? AppColor.primary : AppColor.cardBackground)
                    .foregroundStyle(vm.selectedTab == tab ? .white : AppColor.textMain)
                    .clipShape(Capsule())
                    .shadow(color: vm.selectedTab == tab ? AppColor.primary.opacity(0.3) : .clear, radius: 4, y: 2)
                }
            }
            Spacer()
        }
    }

    // MARK: - 內容區

    @ViewBuilder
    private var contentArea: some View {
        switch vm.selectedTab {
        case .volumes:
            volumesList
        case .trades:
            tradesList
        case .bigOrders:
            bigOrdersList
        }
    }

    // MARK: - 分價量表

    private var volumesList: some View {
        VStack(spacing: 8) {
            // 排序切換
            HStack {
                Text("分價量表")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                ForEach(VolumeSortMode.allCases) { mode in
                    Button {
                        vm.volumeSortMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.warmCaption2())
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(vm.volumeSortMode == mode ? AppColor.primary.opacity(0.15) : Color.clear)
                            .foregroundStyle(vm.volumeSortMode == mode ? AppColor.primary : AppColor.textSecondary)
                            .clipShape(Capsule())
                    }
                }
            }

            // 表頭
            HStack {
                Text("價格")
                    .frame(width: 60, alignment: .leading)
                Text("成交量分佈")
                Spacer()
                Text("量(張)")
                    .frame(width: 55, alignment: .trailing)
                Text("佔比")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(AppColor.textSecondary)

            // 資料列
            ForEach(vm.sortedVolumeRows) { row in
                volumeBar(row)
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func volumeBar(_ row: IntradayAnalysisViewModel.VolumeRow) -> some View {
        let maxVol = vm.maxVolume
        let totalWidth: CGFloat = 1.0 // ratio
        let ratio = maxVol > 0 ? CGFloat(row.volume) / CGFloat(maxVol) : 0
        let askRatio = row.volume > 0 ? CGFloat(row.volumeAtAsk) / CGFloat(row.volume) : 0

        return HStack(spacing: 4) {
            // 價格
            Text(String(format: "%.2f", row.price))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 60, alignment: .leading)

            // 水平柱
            GeometryReader { geo in
                let barWidth = geo.size.width * ratio * totalWidth
                let askWidth = barWidth * askRatio
                let bidWidth = barWidth - askWidth

                HStack(spacing: 0) {
                    // 外盤（綠）
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColor.secondary.opacity(0.7))
                        .frame(width: max(0, askWidth), height: 14)
                    // 內盤（珊瑚）
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColor.softUp.opacity(0.7))
                        .frame(width: max(0, bidWidth), height: 14)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 14)

            // 成交量（張）
            Text("\(row.volume / 1000)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 55, alignment: .trailing)

            // 佔比
            Text(String(format: "%.1f%%", row.percentage))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 18)
    }

    // MARK: - 成交明細

    private var tradesList: some View {
        VStack(spacing: 0) {
            // 表頭
            HStack {
                Text("時間")
                    .frame(width: 65, alignment: .leading)
                Text("價格")
                    .frame(width: 65, alignment: .trailing)
                Text("量(股)")
                    .frame(width: 60, alignment: .trailing)
                Spacer()
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            AppColor.divider.frame(height: 0.5)

            // 資料列
            ForEach(Array(vm.tradeRows.enumerated()), id: \.element.id) { index, row in
                tradeRow(row, previousPrice: index + 1 < vm.tradeRows.count ? vm.tradeRows[index + 1].price : nil)

                if index < vm.tradeRows.count - 1 {
                    AppColor.divider.opacity(0.3).frame(height: 0.5)
                        .padding(.horizontal, 12)
                }
            }
        }
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func tradeRow(_ row: IntradayAnalysisViewModel.TradeRow, previousPrice: Double?) -> some View {
        let priceColor: Color = {
            guard let prev = previousPrice else { return AppColor.textMain }
            if row.price > prev { return AppColor.softUp }
            if row.price < prev { return AppColor.softDown }
            return AppColor.textMain
        }()

        return HStack {
            Text(row.time)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 65, alignment: .leading)

            Text(String(format: "%.2f", row.price))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(priceColor)
                .frame(width: 65, alignment: .trailing)

            Text("\(row.size)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 60, alignment: .trailing)

            Spacer()

            if row.isBigOrder {
                Text("大單")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColor.primary.opacity(0.15))
                    .foregroundStyle(AppColor.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - 大單追蹤

    private var bigOrdersList: some View {
        VStack(spacing: 8) {
            // 門檻選擇
            HStack {
                Text("大單門檻")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                ForEach(BigOrderThreshold.allCases) { threshold in
                    Button {
                        vm.bigOrderThreshold = threshold
                    } label: {
                        Text(threshold.label)
                            .font(.warmCaption2())
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(vm.bigOrderThreshold == threshold ? AppColor.primary.opacity(0.15) : Color.clear)
                            .foregroundStyle(vm.bigOrderThreshold == threshold ? AppColor.primary : AppColor.textSecondary)
                            .clipShape(Capsule())
                    }
                }
            }

            // 大單摘要
            if !vm.bigOrders.isEmpty {
                HStack {
                    WarmInfoBadge(
                        title: "大單筆數",
                        value: "\(vm.bigOrders.count) 筆"
                    )
                    Spacer()
                    WarmInfoBadge(
                        title: "大單總量",
                        value: vm.formatVolume(vm.bigOrderTotalSize)
                    )
                    Spacer()
                    WarmInfoBadge(
                        title: "佔總量",
                        value: vm.totalVolume > 0
                            ? String(format: "%.1f%%", Double(vm.bigOrderTotalSize) / Double(vm.totalVolume) * 100)
                            : "—"
                    )
                }
            }

            // 大單列表
            if vm.bigOrders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(AppColor.textSecondary.opacity(0.4))
                    Text("目前無大單紀錄")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    // 表頭
                    HStack {
                        Text("時間")
                            .frame(width: 65, alignment: .leading)
                        Text("價格")
                            .frame(width: 65, alignment: .trailing)
                        Text("量(股)")
                            .frame(width: 70, alignment: .trailing)
                        Spacer()
                        Text("量(張)")
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    AppColor.divider.frame(height: 0.5)

                    ForEach(vm.bigOrders) { order in
                        HStack {
                            Text(order.time)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(width: 65, alignment: .leading)

                            Text(String(format: "%.2f", order.price))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppColor.textMain)
                                .frame(width: 65, alignment: .trailing)

                            Text("\(order.size)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppColor.primary)
                                .frame(width: 70, alignment: .trailing)

                            Spacer()

                            Text("\(order.size / 1000)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppColor.primary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)

                        AppColor.divider.opacity(0.3).frame(height: 0.5)
                            .padding(.horizontal, 12)
                    }
                }
                .background(AppColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - 狀態視圖

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(AppColor.primary)
            Text("載入盤中資料...")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textSecondary.opacity(0.4))
            Text(message)
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                vm.load()
            } label: {
                Text("重試")
                    .font(.warmCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppColor.primary)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textSecondary.opacity(0.4))
            Text("目前非交易時間或無成交資料")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        IntradayAnalysisView(symbol: "2330")
    }
}
