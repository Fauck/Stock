//
//  OnboardingView.swift
//  Stock
//
//  Created by bokmacdev on 2026/9/15.
//

import SwiftUI

/// 新手引導頁面：4 頁 PageTabView 介紹 app 核心功能
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 略過按鈕
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("略過") {
                            hasCompletedOnboarding = true
                        }
                        .font(.warmBody())
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                    }
                }
                .frame(height: 44)

                // 頁面內容
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    calendarPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }

    // MARK: - 第 1 頁：歡迎

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppColor.primary)

            VStack(spacing: 12) {
                Text("股票筆記")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textMain)

                Text("你的投資筆記本")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(spacing: 16) {
                featureStep(icon: "square.and.pencil", text: "紀錄每一筆交易")
                featureStep(icon: "chart.line.uptrend.xyaxis", text: "追蹤持有庫存表現")
                featureStep(icon: "lightbulb.fill", text: "分析買賣時機")
            }
            .padding(.top, 20)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 第 2 頁：核心功能

    private var featuresPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(AppColor.primary)

            VStack(spacing: 12) {
                Text("智能分析")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textMain)

                Text("一目瞭然的技術指標")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 20) {
                featureRow(
                    icon: "arrow.left.arrow.right",
                    title: "均線扣抵值預測",
                    subtitle: "預判未來均線走勢方向"
                )
                featureRow(
                    icon: "star.fill",
                    title: "買入評分分析",
                    subtitle: "多維度評估買入時機"
                )
                featureRow(
                    icon: "chart.bar.fill",
                    title: "K 線型態辨識",
                    subtitle: "自動偵測關鍵 K 線訊號"
                )
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 第 3 頁：行事曆

    private var calendarPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundStyle(AppColor.primary)

            VStack(spacing: 12) {
                Text("交易行事曆")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textMain)

                Text("回顧每一個交易日")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                calendarFeature(icon: "circle.fill", color: AppColor.softUp, text: "紅點標記買進日期")
                calendarFeature(icon: "circle.fill", color: AppColor.softDown, text: "藍點標記賣出日期")
                calendarFeature(icon: "hand.tap.fill", color: AppColor.primary, text: "長按查看當日交易明細")
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 第 4 頁：開始使用

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppColor.secondary)

            VStack(spacing: 12) {
                Text("準備就緒！")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textMain)

                Text("前往「工具箱 → 新增投資」\n開始你的第一筆紀錄")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("開始使用")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 子元件

    private func featureStep(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColor.primary)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textMain)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppColor.primary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.textMain)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private func calendarFeature(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textMain)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
