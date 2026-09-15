//
//  DataTransferView.swift
//  Stock
//
//  Created by bokmacdev on 2026/5/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 資料備份頁面：匯出與匯入投資紀錄
struct DataTransferView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Investment.buyDate, order: .reverse)
    private var allInvestments: [Investment]

    @Query private var allJournals: [TradeJournal]

    @State private var vm = DataTransferViewModel()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    exportCard
                    importCard
                    infoCard
                }
                .padding(16)
            }
        }
        .navigationTitle("資料備份")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $vm.showingShareSheet) {
            if let url = vm.backupFileURL {
                ShareSheetView(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .fileImporter(
            isPresented: $vm.showingFileImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    vm.fileSelected(.success(url))
                }
            case .failure(let error):
                vm.fileSelected(.failure(error))
            }
        }
        .alert("選擇匯入模式", isPresented: $vm.showingImportModeAlert) {
            Button("合併（保留現有資料）") {
                vm.confirmImport(mode: .merge, context: modelContext)
            }
            Button("取代（清除後匯入）", role: .destructive) {
                vm.confirmImport(mode: .replace, context: modelContext)
            }
            Button("取消", role: .cancel) {
                vm.pendingImportURL = nil
            }
        } message: {
            Text("「合併」會略過已存在的紀錄\n「取代」會先刪除所有現有紀錄再匯入")
        }
        .alert("匯入結果", isPresented: $vm.showingImportResult) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(vm.importResultMessage)
        }
        .alert("錯誤", isPresented: $vm.showingError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
        .onAppear {
            vm.allInvestments = allInvestments
            vm.allJournals = allJournals
        }
        .onChange(of: allInvestments) { _, newValue in vm.allInvestments = newValue }
        .onChange(of: allJournals) { _, newValue in vm.allJournals = newValue }
    }

    // MARK: - 匯出卡片

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundStyle(AppColor.primary)
                Text("匯出備份")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text("\(allInvestments.count) 筆紀錄")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            AppColor.divider.frame(height: 1)

            Text("將所有投資紀錄匯出為備份檔案，可透過 AirDrop、iCloud Drive 等方式傳送至其他裝置。")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)

            Button {
                vm.exportBackup()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("匯出備份檔")
                }
                .font(.warmSubheadline())
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(allInvestments.isEmpty ? AppColor.textSecondary : AppColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .smallShadow()
            }
            .disabled(allInvestments.isEmpty)
        }
        .cardStyle()
    }

    // MARK: - 匯入卡片

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundStyle(AppColor.secondary)
                Text("匯入備份")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
            }

            AppColor.divider.frame(height: 1)

            Text("從備份檔案匯入投資紀錄。支援「合併」或「取代」兩種模式。")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)

            Button {
                vm.startImport()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.doc.fill")
                    Text("選擇備份檔")
                }
                .font(.warmSubheadline())
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColor.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .smallShadow()
            }
        }
        .cardStyle()
    }

    // MARK: - 說明卡片

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppColor.textSecondary)
                Text("備份說明")
                    .font(.warmCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                infoRow("備份包含所有投資紀錄（含已平倉與部分賣出紀錄）")
                infoRow("備份檔案格式為 .stockbackup（JSON）")
                infoRow("「合併」模式會保留現有資料，僅新增缺少的紀錄")
                infoRow("「取代」模式會清除所有現有資料後匯入")
                infoRow("建議定期備份以防資料遺失")
            }
        }
        .padding(14)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
    }

    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·")
                .foregroundStyle(AppColor.textSecondary)
            Text(text)
                .font(.warmCaption2())
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        DataTransferView()
    }
    .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
