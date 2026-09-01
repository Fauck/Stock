import SwiftUI

/// 市場掃描頁面：漲跌幅排行、成交量排行
struct MarketScanView: View {
    @State private var vm = MarketScanViewModel()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 篩選列
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if vm.isLoading && vm.items.isEmpty {
                    loadingState
                } else if let error = vm.errorMessage, vm.items.isEmpty {
                    errorState(error)
                } else if vm.items.isEmpty {
                    emptyState
                } else {
                    rankingList
                }
            }
        }
        .navigationTitle("市場掃描")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.load()
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading)
            }
        }
        .task {
            vm.load()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // 分類選擇
            HStack(spacing: 6) {
                ForEach(ScanCategory.allCases) { cat in
                    Button {
                        vm.selectCategory(cat)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 9))
                            Text(cat.rawValue)
                        }
                        .font(.warmCaption2())
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(vm.category == cat ? AppColor.primary : AppColor.cardBackground)
                        .foregroundStyle(vm.category == cat ? .white : AppColor.textMain)
                        .clipShape(Capsule())
                        .shadow(color: vm.category == cat ? AppColor.primary.opacity(0.3) : .clear, radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // 市場選擇
                ForEach(ScanMarket.allCases) { mkt in
                    Button {
                        vm.selectMarket(mkt)
                    } label: {
                        Text(mkt.rawValue)
                            .font(.warmCaption2())
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(vm.market == mkt ? AppColor.textSecondary : AppColor.background)
                            .foregroundStyle(vm.market == mkt ? .white : AppColor.textSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // 更新時間
            if let time = vm.lastUpdated {
                HStack {
                    Spacer()
                    Text("更新 \(time)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                    .tint(AppColor.primary)
                Text("載入排行資料...")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(AppColor.textSecondary.opacity(0.4))
                Text(message)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    vm.load()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("重試")
                    }
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("無排行資料")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
    }

    // MARK: - Ranking List

    private var rankingList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 表頭
                listHeader
                    .padding(.horizontal, 16)

                // 排行項目
                ForEach(Array(vm.items.enumerated()), id: \.element.id) { index, item in
                    rankRow(index: index + 1, item: item)
                        .padding(.horizontal, 16)

                    if index < vm.items.count - 1 {
                        AppColor.divider.opacity(0.5)
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var listHeader: some View {
        HStack {
            Text("#")
                .frame(width: 22, alignment: .center)
            Text("股票")
                .frame(minWidth: 70, alignment: .leading)
            Spacer()
            if vm.category == .mostActive {
                Text("成交量")
                    .frame(width: 60, alignment: .trailing)
            }
            Text("現價")
                .frame(width: 55, alignment: .trailing)
            Text("漲跌%")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(AppColor.textSecondary.opacity(0.7))
        .padding(.vertical, 6)
    }

    private func rankRow(index: Int, item: ScanItem) -> some View {
        let isUp = item.change >= 0
        let changeColor = item.change == 0 ? AppColor.textSecondary :
            (isUp ? AppColor.softUp : AppColor.softDown)

        return HStack(spacing: 0) {
            // 排名
            Text("\(index)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(index <= 3 ? AppColor.primary : AppColor.textSecondary)
                .frame(width: 22, alignment: .center)

            // 股名 + 代號
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.warmCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.textMain)
                    .lineLimit(1)
                Text(item.symbol)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(minWidth: 70, alignment: .leading)
            .padding(.leading, 6)

            Spacer()

            // 成交量（僅成交量排行）
            if vm.category == .mostActive {
                Text(vm.formatVolume(item.volume))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 60, alignment: .trailing)
            }

            // 現價
            Text(formatPrice(item.closePrice))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 55, alignment: .trailing)

            // 漲跌幅
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%+.2f%%", item.changePercent))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text(String(format: "%+.2f", item.change))
                    .font(.system(size: 9, design: .rounded))
            }
            .foregroundStyle(changeColor)
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    private func formatPrice(_ price: Double) -> String {
        price >= 100 ? String(format: "%.0f", price) : String(format: "%.2f", price)
    }
}

#Preview {
    NavigationStack {
        MarketScanView()
    }
}
