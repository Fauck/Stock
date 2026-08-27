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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
