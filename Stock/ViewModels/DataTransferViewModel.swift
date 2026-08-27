//
//  DataTransferViewModel.swift
//  Stock
//
//  Created by bokmacdev on 2026/5/26.
//

import Foundation
import SwiftData

/// 匯入模式
enum ImportMode {
    case merge    // 合併：UUID 重複則跳過
    case replace  // 取代：清除現有後匯入
}

/// 匯入結果
struct ImportResult {
    let totalInFile: Int
    let inserted: Int
    let skipped: Int
    let replaced: Int
}

@Observable
final class DataTransferViewModel {
    // MARK: - 資料（由 @Query 橋接）

    var allInvestments: [Investment] = []
    var allJournals: [TradeJournal] = []

    // MARK: - 匯出狀態

    var backupFileURL: URL?
    var showingShareSheet: Bool = false

    // MARK: - 匯入狀態

    var showingFileImporter: Bool = false
    var showingImportModeAlert: Bool = false
    var pendingImportURL: URL?
    var showingImportResult: Bool = false
    var importResultMessage: String = ""
    var showingError: Bool = false
    var errorMessage: String = ""

    // MARK: - 匯出

    func exportBackup() {
        guard let url = Investment.exportJSON(from: allInvestments, journals: allJournals) else {
            errorMessage = "匯出失敗，請稍後再試"
            showingError = true
            return
        }
        backupFileURL = url
        showingShareSheet = true
    }

    // MARK: - 匯入

    func startImport() {
        showingFileImporter = true
    }

    func fileSelected(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            pendingImportURL = url
            showingImportModeAlert = true
        case .failure(let error):
            errorMessage = "無法讀取檔案：\(error.localizedDescription)"
            showingError = true
        }
    }

    func confirmImport(mode: ImportMode, context: ModelContext) {
        guard let url = pendingImportURL else { return }

        guard let result = performImport(from: url, mode: mode, context: context) else {
            errorMessage = "匯入失敗：檔案格式不正確或已損壞"
            showingError = true
            pendingImportURL = nil
            return
        }

        switch mode {
        case .merge:
            importResultMessage = "匯入完成！\n共 \(result.totalInFile) 筆紀錄\n新增 \(result.inserted) 筆\n略過 \(result.skipped) 筆（已存在）"
        case .replace:
            importResultMessage = "匯入完成！\n已刪除原有 \(result.replaced) 筆紀錄\n匯入 \(result.inserted) 筆紀錄"
        }
        showingImportResult = true
        pendingImportURL = nil
    }

    // MARK: - 匯入邏輯

    private func performImport(from url: URL, mode: ImportMode, context: ModelContext) -> ImportResult? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(InvestmentBackup.self, from: data) else { return nil }

        switch mode {
        case .merge:
            return performMerge(backup: backup, context: context)
        case .replace:
            return performReplace(backup: backup, context: context)
        }
    }

    private func performMerge(backup: InvestmentBackup, context: ModelContext) -> ImportResult {
        let descriptor = FetchDescriptor<Investment>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingIDs = Set(existing.map(\.id))

        var inserted = 0
        var skipped = 0
        for codable in backup.investments {
            if existingIDs.contains(codable.id) {
                skipped += 1
            } else {
                let investment = Investment.fromCodable(codable)
                context.insert(investment)
                inserted += 1
            }
        }

        // 合併交易日誌
        if let journals = backup.journals {
            let journalDescriptor = FetchDescriptor<TradeJournal>()
            let existingJournals = (try? context.fetch(journalDescriptor)) ?? []
            let existingJournalIDs = Set(existingJournals.map(\.id))

            for codable in journals {
                if !existingJournalIDs.contains(codable.id) {
                    let journal = TradeJournal.fromCodable(codable)
                    context.insert(journal)
                }
            }
        }

        return ImportResult(
            totalInFile: backup.investments.count,
            inserted: inserted,
            skipped: skipped,
            replaced: 0
        )
    }

    private func performReplace(backup: InvestmentBackup, context: ModelContext) -> ImportResult {
        let descriptor = FetchDescriptor<Investment>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let deletedCount = existing.count
        for item in existing {
            context.delete(item)
        }

        // 刪除所有現有日誌
        let journalDescriptor = FetchDescriptor<TradeJournal>()
        let existingJournals = (try? context.fetch(journalDescriptor)) ?? []
        for journal in existingJournals {
            context.delete(journal)
        }

        for codable in backup.investments {
            let investment = Investment.fromCodable(codable)
            context.insert(investment)
        }

        // 匯入日誌
        if let journals = backup.journals {
            for codable in journals {
                let journal = TradeJournal.fromCodable(codable)
                context.insert(journal)
            }
        }

        return ImportResult(
            totalInFile: backup.investments.count,
            inserted: backup.investments.count,
            skipped: 0,
            replaced: deletedCount
        )
    }
}
