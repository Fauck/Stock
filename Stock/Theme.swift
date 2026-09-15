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

// MARK: - 間距代幣

/// 統一的間距系統，基於 4pt 倍數
enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let s:   CGFloat = 6
    static let m:   CGFloat = 8
    static let l:   CGFloat = 10
    static let ml:  CGFloat = 12
    static let lg:  CGFloat = 14
    static let xl:  CGFloat = 16
}

// MARK: - 圓角代幣

/// 統一的圓角半徑系統
enum AppRadius {
    static let micro: CGFloat = 2    // progress bars, chart bars
    static let tiny:  CGFloat = 3    // win-rate mini bars
    static let tag:   CGFloat = 4    // chart element labels
    static let pill:  CGFloat = 8    // filter chips, stop-loss pills
    static let inner: CGFloat = 10   // metric cells, detail rows
    static let field: CGFloat = 12   // form fields, banners, day cells
    static let panel: CGFloat = 16   // sheet panels
    static let card:  CGFloat = 20   // outer cards
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

    /// 圓體微型（9pt）— chart labels, sub-labels
    static func warmMicro(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 9, weight: weight, design: .rounded)
    }

    /// 圓體三級標籤（10pt）— pills, section headers
    static func warmTertiary(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 10, weight: weight, design: .rounded)
    }

    /// 圓體次要資料（11pt）— qty, avg cost, metadata
    static func warmSecondaryData(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 11, weight: weight, design: .rounded)
    }

    /// 圓體資料值（12pt）— metric values, inputs
    static func warmDataValue(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 12, weight: weight, design: .rounded)
    }
}

// MARK: - 卡片樣式修飾器

/// 通用卡片樣式：圓角 20pt、白底、柔和陰影
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.xl)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .cardShadow()
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - 陰影修飾器

extension View {
    /// 卡片陰影：較深、較大範圍
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    /// 小型陰影：輕微浮起
    func smallShadow() -> some View {
        shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    /// 列陰影：微弱分層
    func rowShadow() -> some View {
        shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    /// 中型陰影：面板層級
    func mediumShadow() -> some View {
        shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
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

// MARK: - 情緒分數選擇器

/// 情緒分數膠囊按鈕列：1 (極度恐慌) ~ 5 (極度貪婪)
struct EmotionScorePicker: View {
    @Binding var selection: Int?

    private let scores: [(value: Int, label: String, color: Color)] = [
        (1, "1 恐慌", AppColor.softDown),
        (2, "2 不安", AppColor.softDown.opacity(0.6)),
        (3, "3 中立", AppColor.textSecondary),
        (4, "4 樂觀", AppColor.softUp.opacity(0.6)),
        (5, "5 貪婪", AppColor.softUp),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("當下情緒分數")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            HStack(spacing: 4) {
                ForEach(scores, id: \.value) { score in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = selection == score.value ? nil : score.value
                        }
                    } label: {
                        Text(score.label)
                            .font(.warmCaption2())
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                selection == score.value
                                    ? score.color
                                    : AppColor.background
                            )
                            .foregroundStyle(
                                selection == score.value
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
}

// MARK: - R-Multiple 色彩工具

extension Color {
    /// 根據 R-Multiple 值返回對應色彩
    /// R ≥ 1：綠色、0 < R < 1：橙色、R ≈ -1：灰色、R < -1：紅色警示
    static func rMultipleColor(_ r: Double) -> Color {
        if r >= 1 {
            return AppColor.secondary  // 綠色
        } else if r > 0 {
            return AppColor.softUp     // 橙色
        } else if r >= -1 {
            return AppColor.textSecondary  // 灰色
        } else {
            return AppColor.softDown   // 紅色警示（凹單）
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
// MARK: - 扣抵值走勢迷你圖

/// 顯示單條均線未來 N 日扣抵值走勢，以現價為基準線
struct DeductionForecastChart: View {
    let info: TechnicalIndicators.MADeductionInfo
    let height: CGFloat

    init(info: TechnicalIndicators.MADeductionInfo, height: CGFloat = 44) {
        self.info = info
        self.height = height
    }

    var body: some View {
        let points = info.futureDeductions
        guard points.count >= 2 else { return AnyView(EmptyView()) }

        let prices = points.map(\.deductionPrice)
        let currentPrice = info.currentPrice

        // Y 軸範圍：扣抵值 + 現價中取 min/max
        let allValues = prices + [currentPrice]
        let minVal = allValues.min()!
        let maxVal = allValues.max()!
        let range = maxVal - minVal
        let safeRange = range > 0 ? range : 1

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                // 標題列：均線名稱 + 翻轉提示
                HStack(spacing: 4) {
                    Text(info.periodLabel)
                        .font(.warmTertiary(.semibold))
                        .foregroundStyle(AppColor.textMain)
                    if let flip = info.flipDay {
                        Text("第\(flip)天翻轉")
                            .font(.warmMicro(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }

                // 圖表
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    // 現價基準線 Y 位置
                    let priceY = h * (1 - (currentPrice - minVal) / safeRange)

                    // 扣抵值各點座標
                    let stepX = w / CGFloat(points.count - 1)
                    let coords: [CGPoint] = points.enumerated().map { i, p in
                        let x = stepX * CGFloat(i)
                        let y = h * (1 - (p.deductionPrice - minVal) / safeRange)
                        return CGPoint(x: x, y: y)
                    }

                    // 現價基準線
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: priceY))
                        path.addLine(to: CGPoint(x: w, y: priceY))
                    }
                    .stroke(AppColor.textSecondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    // 扣抵值折線（分段著色）
                    ForEach(0..<coords.count - 1, id: \.self) { i in
                        Path { path in
                            path.move(to: coords[i])
                            path.addLine(to: coords[i + 1])
                        }
                        .stroke(
                            segmentColor(deduction: prices[i], nextDeduction: prices[i + 1], currentPrice: currentPrice),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                    }

                    // 各點圓點
                    ForEach(0..<coords.count, id: \.self) { i in
                        Circle()
                            .fill(prices[i] < currentPrice ? AppColor.softUp : (prices[i] > currentPrice ? AppColor.softDown : AppColor.textSecondary))
                            .frame(width: 5, height: 5)
                            .position(coords[i])
                    }

                    // 左側「現價」標籤
                    Text("現價")
                        .font(.system(size: 7, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                        .position(x: 14, y: priceY - 7)
                }
                .frame(height: height)

                // X 軸標籤
                HStack {
                    ForEach(0..<points.count, id: \.self) { i in
                        Text(i == 0 ? "今" : "+\(i)")
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                        if i < points.count - 1 {
                            Spacer()
                        }
                    }
                }
            }
        )
    }

    private func segmentColor(deduction: Double, nextDeduction: Double, currentPrice: Double) -> Color {
        let avgDeduction = (deduction + nextDeduction) / 2
        if avgDeduction < currentPrice { return AppColor.softUp }
        if avgDeduction > currentPrice { return AppColor.softDown }
        return AppColor.textSecondary
    }
}

