import Foundation

/// 用於存放敏感金鑰的結構
/// 此檔案已被加入到 .gitignore 中，不會被提交上傳至 Git 倉庫。
enum Secrets: Sendable {
    // TODO: 請在此處替換為您專屬的富果 API Key (Fugle API Token)
    // 申請網址：https://developer.fugle.tw/
    nonisolated(unsafe) static let fugleAPIKey = "NjhkN2JjOTUtZDU0NC00MmFmLTkzMTEtOThlM2I1MTBiN2FkIDAzMTZlZWI4LTQ2YWEtNGUyOS05NGY5LTY2ZmUxMzA4MmYzNQ=="
    //FUGLE_API_KEY='NjhkN2JjOTUtZDU0NC00MmFmLTkzMTEtOThlM2I1MTBiN2FkIDAzMTZlZWI4LTQ2YWEtNGUyOS05NGY5LTY2ZmUxMzA4MmYzNQ=='
}
