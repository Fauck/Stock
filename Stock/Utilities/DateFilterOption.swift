import Foundation

/// 日期篩選區間列舉
enum DateFilterOption: String, CaseIterable, Identifiable {
    case all = "全部"
    case week = "一週內"
    case month = "一個月內"
    case thisMonth = "本月"
    case custom = "自訂區間"

    var id: String { rawValue }
}
