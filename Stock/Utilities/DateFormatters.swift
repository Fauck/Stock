import Foundation

/// 集中管理的日期格式化工具，避免重複建立 DateFormatter
enum AppDateFormatter {
    /// "yyyy/MM/dd"
    static let slashDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// "yyyy/MM/dd（EE）"
    static let slashDateWithWeekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy/MM/dd（EE）"
        return f
    }()

    /// "yyyy 年 M 月"
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy 年 M 月"
        return f
    }()

    /// "M 月 d 日（EEEE）"
    static let dayFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M 月 d 日（EEEE）"
        return f
    }()

    /// "yyyy 年 M 月 d 日（EEEE）"
    static let fullDateWithWeekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy 年 M 月 d 日（EEEE）"
        return f
    }()

    /// "yyyyMMdd_HHmmss" — CSV 匯出檔名用
    static let fileTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()
}
