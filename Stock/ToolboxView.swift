//
//  ToolboxView.swift
//  Stock
//
//  Created by bokmacdev on 2026/5/26.
//

import SwiftUI

/// 工具箱頁面：提供各種實用小工具
struct ToolboxView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        toolCard(
                            title: "交易績效儀表板",
                            subtitle: "勝率趨勢、情緒分析、R值紀律與標的排行",
                            icon: "chart.xyaxis.line",
                            iconColor: AppColor.primary,
                            destination: DashboardView()
                        )

                        toolCard(
                            title: "交易日誌",
                            subtitle: "瀏覽所有交易日誌，查看 R-Multiple 統計與停損紀律分析",
                            icon: "book.fill",
                            iconColor: AppColor.softUp,
                            destination: TradeJournalListView()
                        )

                        toolCard(
                            title: "房貸試算",
                            subtitle: "計算每月還款金額、總利息與攤還表",
                            icon: "house.fill",
                            iconColor: AppColor.primary,
                            destination: MortgageCalculatorView()
                        )

                        toolCard(
                            title: "買入分析",
                            subtitle: "輸入股票代號，取得多空指標綜合評分與買入建議",
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: AppColor.secondary,
                            destination: BuyAnalysisView()
                        )

                        toolCard(
                            title: "參數設定",
                            subtitle: "交易費用、均線、RSI、KDJ、MACD、布林通道等參數",
                            icon: "slider.horizontal.3",
                            iconColor: AppColor.primary,
                            destination: TechnicalSettingsView()
                        )

                        toolCard(
                            title: "資料備份",
                            subtitle: "匯出或匯入投資紀錄備份檔案",
                            icon: "externaldrive.fill",
                            iconColor: AppColor.secondary,
                            destination: DataTransferView()
                        )
                    }
                    .padding(16)
                }
            }
            .navigationTitle("工具箱")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - 工具卡片（可複用）

    private func toolCard<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.textMain)
                    Text(subtitle)
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ToolboxView()
}
