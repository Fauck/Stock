import Foundation
import SwiftUI

/// 大盤狀態：記錄買入或賣出時的市場氛圍
enum MarketCondition: String, CaseIterable, Identifiable, Codable {
    case bigUp = "大漲"
    case smallUp = "小漲"
    case flat = "平盤"
    case smallDown = "小跌"
    case bigDown = "大跌"

    var id: String { rawValue }

    /// SF Symbol 圖示
    var icon: String {
        switch self {
        case .bigUp:    return "arrow.up.right.circle.fill"
        case .smallUp:  return "arrow.up.right"
        case .flat:     return "minus.circle"
        case .smallDown: return "arrow.down.right"
        case .bigDown:  return "arrow.down.right.circle.fill"
        }
    }

    /// 顯示色彩
    var color: Color {
        switch self {
        case .bigUp:     return .red
        case .smallUp:   return .red.opacity(0.5)
        case .flat:      return .gray
        case .smallDown: return .green.opacity(0.5)
        case .bigDown:   return .green
        }
    }
}
