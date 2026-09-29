//
//  TechnicalSettingsView.swift
//  Stock
//
//  Created by bokmacdev on 2026/9/1.
//

import SwiftUI

/// 技術指標參數設定頁面
struct TechnicalSettingsView: View {
    @State private var settings = TechnicalSettings.load()
    @State private var feeSettings = TradingFeeSettings.load()
    @State private var showResetAlert = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    feeSection

                    maSection
                    rsiSection
                    kdjSection
                    macdSection
                    bollingerSection
                    atrSection
                    adxSection
                    volumeSection

                    resetButton
                        .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .navigationTitle("參數設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("恢復預設值", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢復預設", role: .destructive) {
                TechnicalSettings.resetToDefaults()
                TradingFeeSettings.resetToDefaults()
                settings = TechnicalSettings.load()
                feeSettings = TradingFeeSettings.load()
            }
        } message: {
            Text("所有參數將恢復為預設值，確定要繼續嗎？")
        }
    }

    // MARK: - 交易費用

    private var feeSection: some View {
        settingsCard(title: "交易費用", icon: "dollarsign.circle") {
            feeSliderRow(
                label: "手續費率",
                value: $feeSettings.commissionRate,
                range: 0.0001...0.002,
                step: 0.000025,
                onSave: { feeSettings.save() }
            )
            Divider()
            feeSliderRow(
                label: "證券交易稅率",
                value: $feeSettings.taxRate,
                range: 0.0005...0.005,
                step: 0.0001,
                onSave: { feeSettings.save() }
            )
            Divider()
            trailingStopRow(
                label: "回撤停利",
                value: $feeSettings.trailingStopPct,
                range: 5...30
            )
            Divider()
            toggleRow(
                label: "賣出建議",
                isOn: $feeSettings.sellRecommendationEnabled
            )
            Divider()
            toggleRow(
                label: "壓力/支撐價位",
                isOn: $feeSettings.supportResistanceEnabled
            )
        }
    }

    /// 費率 Slider（以百分比顯示）
    private func feeSliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.warmBody())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text(String(format: "%.4f%%", value.wrappedValue * 100))
                    .font(.warmBody())
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.primary)
            }
            Slider(value: value, in: range, step: step)
                .tint(AppColor.primary)
                .onChange(of: value.wrappedValue) { onSave() }
        }
    }

    /// 移動停利門檻 Stepper（整數百分比）
    private func trailingStopRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(label)
                .font(.warmBody())
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Text(String(format: "%.0f%%", value.wrappedValue))
                .font(.warmBody())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.primary)
                .frame(minWidth: 40, alignment: .trailing)
            Stepper("", value: value, in: range, step: 5)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { feeSettings.save() }
        }
    }

    /// Toggle 開關列
    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.warmBody())
                .foregroundStyle(AppColor.textMain)
        }
        .tint(AppColor.primary)
        .onChange(of: isOn.wrappedValue) { feeSettings.save() }
    }

    // MARK: - 均線

    private var maSection: some View {
        settingsCard(title: "均線 (MA)", icon: "chart.xyaxis.line") {
            stepperRow(label: "短期均線週期", value: $settings.maShortPeriod, range: 2...50)
            Divider()
            stepperRow(label: "長期均線週期", value: $settings.maLongPeriod, range: 5...200)
        }
    }

    // MARK: - RSI

    private var rsiSection: some View {
        settingsCard(title: "RSI 相對強弱指標", icon: "gauge.with.needle") {
            stepperRow(label: "RSI 週期", value: $settings.rsiPeriod, range: 2...50)
            Divider()
            stepperRow(label: "超買門檻", value: $settings.rsiOverbought, range: 50...95, step: 5)
            Divider()
            stepperRow(label: "超賣門檻", value: $settings.rsiOversold, range: 5...50, step: 5)
        }
    }

    // MARK: - KDJ

    private var kdjSection: some View {
        settingsCard(title: "KDJ 隨機指標", icon: "waveform.path") {
            stepperRow(label: "KDJ 週期", value: $settings.kdjPeriod, range: 5...30)
            Divider()
            stepperRow(label: "K 平滑係數", value: $settings.kdjKSmooth, range: 2...10)
            Divider()
            stepperRow(label: "D 平滑係數", value: $settings.kdjDSmooth, range: 2...10)
        }
    }

    // MARK: - MACD

    private var macdSection: some View {
        settingsCard(title: "MACD 指數平滑異同", icon: "chart.bar.fill") {
            stepperRow(label: "快線週期", value: $settings.macdFastPeriod, range: 5...30)
            Divider()
            stepperRow(label: "慢線週期", value: $settings.macdSlowPeriod, range: 10...60)
            Divider()
            stepperRow(label: "信號線週期", value: $settings.macdSignalPeriod, range: 2...20)
        }
    }

    // MARK: - 布林通道

    private var bollingerSection: some View {
        settingsCard(title: "布林通道 (Bollinger)", icon: "rectangle.compress.vertical") {
            stepperRow(label: "均線週期", value: $settings.bollingerPeriod, range: 5...50)
            Divider()
            sliderRow(label: "標準差倍數", value: $settings.bollingerMultiplier,
                      range: 1.0...3.0, step: 0.1, format: "%.1f")
            Divider()
            sliderRow(label: "收窄門檻", value: $settings.bollingerSqueezeThreshold,
                      range: 0.01...0.20, step: 0.01, format: "%.2f")
            Divider()
            sliderRow(label: "觸軌門檻", value: $settings.bollingerNearBandThreshold,
                      range: 0.01...0.10, step: 0.01, format: "%.2f")
        }
    }

    // MARK: - ATR

    private var atrSection: some View {
        settingsCard(title: "ATR 真實波幅", icon: "arrow.up.and.down") {
            stepperRow(label: "ATR 週期", value: $settings.atrPeriod, range: 5...30)
        }
    }

    // MARK: - ADX

    private var adxSection: some View {
        settingsCard(title: "ADX 趨勢強度", icon: "arrow.up.right") {
            stepperRow(label: "ADX 週期", value: $settings.adxPeriod, range: 5...30)
            Divider()
            stepperRow(label: "強趨勢門檻", value: $settings.adxStrongThreshold, range: 15...40, step: 5)
        }
    }

    // MARK: - 成交量

    private var volumeSection: some View {
        settingsCard(title: "成交量分析", icon: "chart.bar.xaxis") {
            sliderRow(label: "爆量倍數", value: $settings.volumeSurgeMultiplier,
                      range: 1.5...5.0, step: 0.1, format: "%.1fx")
            Divider()
            sliderRow(label: "量增倍數", value: $settings.volumeHighMultiplier,
                      range: 1.0...3.0, step: 0.1, format: "%.1fx")
            Divider()
            sliderRow(label: "量縮倍數", value: $settings.volumeShrinkMultiplier,
                      range: 0.1...0.9, step: 0.1, format: "%.1fx")
            Divider()
            stepperRow(label: "均量週期", value: $settings.volumeMAPeriod, range: 5...60)
        }
    }

    // MARK: - 恢復預設按鈕

    private var resetButton: some View {
        Button {
            showResetAlert = true
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("恢復預設值")
            }
            .font(.warmSubheadline())
            .foregroundStyle(AppColor.softDown)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColor.softDown.opacity(0.1))
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

    /// Stepper 控制列（整數）
    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.warmBody())
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Text("\(value.wrappedValue)")
                .font(.warmBody())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.primary)
                .frame(minWidth: 30, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { settings.save() }
        }
    }

    /// Stepper 控制列（Double 值）
    private func stepperRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(label)
                .font(.warmBody())
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Text(String(format: "%.0f", value.wrappedValue))
                .font(.warmBody())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.primary)
                .frame(minWidth: 30, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { settings.save() }
        }
    }

    /// Slider 控制列
    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.warmBody())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.warmBody())
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.primary)
            }
            Slider(value: value, in: range, step: step)
                .tint(AppColor.primary)
                .onChange(of: value.wrappedValue) { settings.save() }
        }
    }
}

#Preview {
    NavigationStack {
        TechnicalSettingsView()
    }
}
