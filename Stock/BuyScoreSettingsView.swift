import SwiftUI

/// 買入評分權重設定頁面
struct BuyScoreSettingsView: View {
    @State private var settings = BuyScoreSettings.load()
    @State private var showResetAlert = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    maSection
                    macdSection
                    kdjSection
                    rsiSection
                    bollingerSection
                    volumeSection
                    institutionalSection
                    divergenceSection
                    candleSection
                    week52Section

                    resetButton
                        .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .navigationTitle("買入評分權重")
        .navigationBarTitleDisplayMode(.inline)
        .alert("恢復預設值", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢復預設", role: .destructive) {
                BuyScoreSettings.resetToDefaults()
                settings = BuyScoreSettings.load()
            }
        } message: {
            Text("所有買入評分權重將恢復為預設值，確定要繼續嗎？")
        }
    }

    // MARK: - 均線

    private var maSection: some View {
        settingsCard(title: "均線 (MA)", icon: "chart.line.uptrend.xyaxis") {
            stepperRow(label: "金叉", value: $settings.maGoldenCrossPoints)
            Divider()
            stepperRow(label: "死叉", value: $settings.maDeathCrossPoints)
            Divider()
            stepperRow(label: "在 MA5 上方", value: $settings.aboveMA5Points)
            Divider()
            stepperRow(label: "在 MA5 下方", value: $settings.belowMA5Points)
            Divider()
            stepperRow(label: "在 MA20 上方", value: $settings.aboveMA20Points)
            Divider()
            stepperRow(label: "在 MA20 下方", value: $settings.belowMA20Points)
        }
    }

    // MARK: - MACD

    private var macdSection: some View {
        settingsCard(title: "MACD", icon: "waveform.path.ecg") {
            stepperRow(label: "金叉", value: $settings.macdGoldenCrossPoints)
            Divider()
            stepperRow(label: "死叉", value: $settings.macdDeathCrossPoints)
            Divider()
            stepperRow(label: "DIF > 0", value: $settings.macdPositivePoints)
            Divider()
            stepperRow(label: "DIF < 0", value: $settings.macdNegativePoints)
        }
    }

    // MARK: - KDJ

    private var kdjSection: some View {
        settingsCard(title: "KDJ", icon: "chart.xyaxis.line") {
            stepperRow(label: "金叉", value: $settings.kdjGoldenCrossPoints)
            Divider()
            stepperRow(label: "死叉", value: $settings.kdjDeathCrossPoints)
            Divider()
            stepperRow(label: "超賣 (K<20)", value: $settings.kdjOversoldPoints)
            Divider()
            stepperRow(label: "超買 (K>80)", value: $settings.kdjOverboughtPoints)
        }
    }

    // MARK: - RSI

    private var rsiSection: some View {
        settingsCard(title: "RSI", icon: "gauge.with.dots.needle.50percent") {
            stepperRow(label: "超賣", value: $settings.rsiOversoldPoints)
            Divider()
            stepperRow(label: "超買", value: $settings.rsiOverboughtPoints)
        }
    }

    // MARK: - 布林通道

    private var bollingerSection: some View {
        settingsCard(title: "布林通道", icon: "circle.grid.3x3") {
            stepperRow(label: "靠近下軌", value: $settings.bollingerLowerPoints)
            Divider()
            stepperRow(label: "靠近上軌", value: $settings.bollingerUpperPoints)
        }
    }

    // MARK: - 成交量

    private var volumeSection: some View {
        settingsCard(title: "成交量", icon: "chart.bar") {
            stepperRow(label: "量增", value: $settings.volumeSurgePoints)
            Divider()
            stepperRow(label: "量縮", value: $settings.volumeShrinkPoints)
        }
    }

    // MARK: - 法人

    private var institutionalSection: some View {
        settingsCard(title: "法人動態", icon: "building.columns") {
            stepperRow(label: "外資連買", value: $settings.foreignBuyStreakPoints)
            Divider()
            stepperRow(label: "外資連賣", value: $settings.foreignSellStreakPoints)
            Divider()
            stepperRow(label: "投信連買", value: $settings.trustBuyStreakPoints)
            Divider()
            stepperRow(label: "投信連賣", value: $settings.trustSellStreakPoints)
        }
    }

    // MARK: - 背離

    private var divergenceSection: some View {
        settingsCard(title: "背離", icon: "arrow.triangle.swap") {
            stepperRow(label: "RSI 底背離", value: $settings.rsiBullishDivPoints)
            Divider()
            stepperRow(label: "RSI 頂背離", value: $settings.rsiBearishDivPoints)
            Divider()
            stepperRow(label: "MACD 底背離", value: $settings.macdBullishDivPoints)
            Divider()
            stepperRow(label: "MACD 頂背離", value: $settings.macdBearishDivPoints)
        }
    }

    // MARK: - K 線型態

    private var candleSection: some View {
        settingsCard(title: "K 線型態", icon: "chart.bar.doc.horizontal") {
            stepperRow(label: "高可靠度多頭", value: $settings.candleHighBullishPoints)
            Divider()
            stepperRow(label: "高可靠度空頭", value: $settings.candleHighBearishPoints)
            Divider()
            stepperRow(label: "中可靠度多頭", value: $settings.candleMedBullishPoints)
            Divider()
            stepperRow(label: "中可靠度空頭", value: $settings.candleMedBearishPoints)
            Divider()
            stepperRow(label: "低可靠度多頭", value: $settings.candleLowBullishPoints)
            Divider()
            stepperRow(label: "低可靠度空頭", value: $settings.candleLowBearishPoints)
        }
    }

    // MARK: - 52 週位置

    private var week52Section: some View {
        settingsCard(title: "52 週位置", icon: "calendar") {
            stepperRow(label: "接近低點", value: $settings.near52WeekLowPoints)
            Divider()
            stepperRow(label: "接近高點", value: $settings.near52WeekHighPoints)
        }
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button {
            showResetAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text("恢復預設值")
            }
            .font(.warmSubheadline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColor.softDown.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 元件工具

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                Text(title)
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
            }

            VStack(spacing: 10) {
                content()
            }
        }
        .cardStyle()
    }

    private func stepperRow(label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.warmBody())
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Text(value.wrappedValue > 0 ? "+\(value.wrappedValue)" : "\(value.wrappedValue)")
                .font(.warmBody())
                .fontWeight(.medium)
                .foregroundStyle(value.wrappedValue >= 0 ? AppColor.softUp : AppColor.softDown)
                .frame(minWidth: 36, alignment: .trailing)
            Stepper("", value: value, in: -20...20)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { settings.save() }
        }
    }
}

#Preview {
    NavigationStack {
        BuyScoreSettingsView()
    }
}
