//
//  Theme.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/2.
//

import SwiftUI

// MARK: - 自訂色彩系統

/// 溫暖日誌風格的色彩定義
enum AppColor {
    /// 背景色：米黃色 #FAF8F1
    static let background = Color(red: 0.98, green: 0.973, blue: 0.945)
    /// 主色調：溫暖棕色 #A06D40
    static let primary = Color(red: 0.627, green: 0.427, blue: 0.251)
    /// 次要色調：自然綠 #4F7942
    static let secondary = Color(red: 0.310, green: 0.475, blue: 0.259)
    /// 卡片背景色：純白 #FFFFFF
    static let cardBackground = Color.white
    /// 主文字色：深灰 #4A4A4A
    static let textMain = Color(red: 0.290, green: 0.290, blue: 0.290)
    /// 柔和漲色：珊瑚橘 #ED7D60
    static let softUp = Color(red: 0.929, green: 0.490, blue: 0.376)
    /// 柔和跌色：湖水藍綠 #7BBFBF
    static let softDown = Color(red: 0.483, green: 0.749, blue: 0.749)
    /// 次要文字色
    static let textSecondary = Color(red: 0.55, green: 0.53, blue: 0.50)
    /// 分隔線色
    static let divider = Color(red: 0.88, green: 0.86, blue: 0.82)
}

// MARK: - 字體擴展

extension Font {
    /// 圓體標題（大）
    static func warmTitle() -> Font {
        .system(.title2, design: .rounded, weight: .bold)
    }

    /// 圓體標題（中）
    static func warmHeadline() -> Font {
        .system(.headline, design: .rounded, weight: .semibold)
    }

    /// 圓體副標
    static func warmSubheadline() -> Font {
        .system(.subheadline, design: .rounded, weight: .medium)
    }

    /// 圓體內文
    static func warmBody() -> Font {
        .system(.body, design: .rounded)
    }

    /// 圓體小字
    static func warmCaption() -> Font {
        .system(.caption, design: .rounded)
    }

    /// 圓體極小字
    static func warmCaption2() -> Font {
        .system(.caption2, design: .rounded)
    }

    /// 圓體大數字
    static func warmLargeNumber() -> Font {
        .system(.title, design: .rounded, weight: .bold)
    }
}

// MARK: - 卡片樣式修飾器

/// 通用卡片樣式：圓角 20pt、白底、柔和陰影
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - 鍵盤收合修飾器

/// 統一的鍵盤收合邏輯：滑動收合、點擊空白處收合、鍵盤上方「完成」按鈕
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .background(keyboardDismissTapArea)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { hideKeyboard() }
                }
            }
    }

    /// 使用低優先級手勢，只在子視圖不處理點擊時才收合鍵盤
    private var keyboardDismissTapArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { hideKeyboard() }
    }
}

/// 全域鍵盤收合工具
func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

extension View {
    /// 為包含輸入欄位的頁面加入鍵盤收合功能（滑動、點擊、完成按鈕）
    func keyboardDismissable() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

// MARK: - 筆記本底線風格 TextEditor

/// 筆記本風格的文字輸入框，帶有底線裝飾
struct NotebookTextField: View {
    let placeholder: String
    @Binding var text: String
    var lineLimit: Int = 4
    var icon: String = "pencil.line"
    var iconColor: Color = AppColor.primary
    var isFocused: FocusState<Bool>.Binding?

    @FocusState private var internalFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.warmCaption())
                    .foregroundStyle(iconColor)
                Text(placeholder)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            ZStack(alignment: .topLeading) {
                // 底線效果背景
                VStack(spacing: 0) {
                    ForEach(0..<lineLimit, id: \.self) { _ in
                        VStack(spacing: 0) {
                            Spacer()
                            AppColor.divider
                                .frame(height: 1)
                        }
                        .frame(height: 28)
                    }
                }

                // 實際的文字輸入
                TextField("", text: $text, axis: .vertical)
                    .font(.warmBody())
                    .foregroundStyle(AppColor.textMain)
                    .lineLimit(1...lineLimit)
                    .padding(.top, 4)
                    .focused(isFocused ?? $internalFocus)
            }
        }
        .padding(12)
        .background(AppColor.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 溫暖風格 InfoBadge

/// 重新設計的資訊標籤：圓角背景、溫暖色系
struct WarmInfoBadge: View {
    let title: String
    let value: String
    var valueColor: Color = AppColor.textMain

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.warmCaption2())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmCaption())
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 損益顏色工具

extension Color {
    /// 根據損益值返回柔和漲跌色
    static func profitLossColor(_ value: Double) -> Color {
        value >= 0 ? AppColor.softUp : AppColor.softDown
    }
}

// MARK: - 狀態標籤元件

struct WarmStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.warmCaption2())
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - 大盤狀態選擇器

/// 水平膠囊按鈕列，選擇大盤狀態
struct MarketConditionPicker: View {
    @Binding var selection: MarketCondition?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(AppColor.primary)
                Text("大盤狀態")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(MarketCondition.allCases) { condition in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = selection == condition ? nil : condition
                        }
                    } label: {
                        Text(condition.rawValue)
                            .font(.warmCaption2())
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selection == condition
                                    ? marketConditionColor(condition)
                                    : AppColor.background
                            )
                            .foregroundStyle(
                                selection == condition
                                    ? .white
                                    : AppColor.textMain
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func marketConditionColor(_ condition: MarketCondition) -> Color {
        switch condition {
        case .bigUp:    return AppColor.softUp
        case .smallUp:  return AppColor.softUp.opacity(0.7)
        case .flat:     return AppColor.textSecondary
        case .smallDown: return AppColor.softDown.opacity(0.7)
        case .bigDown:  return AppColor.softDown
        }
    }
}

// MARK: - 系統分享表單

/// 包裝 UIActivityViewController 供 SwiftUI 使用
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
