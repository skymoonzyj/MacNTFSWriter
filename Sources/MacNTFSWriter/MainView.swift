import MacNTFSWriterCore
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        NavigationSplitView {
            VolumeListView(viewModel: viewModel)
                .navigationTitle("NTFS Writer for Mac")
        } detail: {
            VolumeDetailView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await viewModel.refreshAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isBusy)
            }
        }
        .task {
            viewModel.start()
        }
    }
}

private struct VolumeListView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        List(selection: $viewModel.selectedVolumeID) {
            Section("NTFS 分区") {
                if viewModel.volumes.isEmpty {
                    EmptyStateView(title: "未发现 NTFS 分区", systemImage: "externaldrive.badge.questionmark")
                        .frame(minHeight: 180)
                } else {
                    ForEach(viewModel.volumes) { volume in
                        VolumeRow(volume: volume)
                            .tag(volume.id)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            DependencySummary(
                status: viewModel.dependencies,
                isBusy: viewModel.isBusy,
                actionTitle: viewModel.dependencyActionTitle,
                action: viewModel.performDependencyAction
            )
                .padding()
                .background(.bar)
        }
    }
}

private struct VolumeRow: View {
    let volume: NTFSVolume

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(volume.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(volume.deviceNode) · \(volume.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: volume.isMounted ? "externaldrive.fill" : "externaldrive")
                .foregroundStyle(volume.isMounted ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct VolumeDetailView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        if let volume = viewModel.selectedVolume {
            VStack(alignment: .leading, spacing: 22) {
                Header(volume: volume)
                StatusGrid(volume: volume, dependencies: viewModel.dependencies, health: viewModel.volumeHealthStatus)
                HealthPanel(status: viewModel.volumeHealthStatus)
                ActionBar(viewModel: viewModel, volume: volume)
                SafetyNotes()

                if let warning = viewModel.lastWarning {
                    WarningPanel(message: warning)
                }

                if let error = viewModel.lastError {
                    ErrorPanel(message: error)
                }

                if let installLog = viewModel.installLog {
                    InstallLogPanel(log: installLog)
                }

                if !viewModel.operationLog.isEmpty {
                    OperationLogPanel(entries: viewModel.operationLog)
                }

                Spacer()

                HStack(spacing: 8) {
                    if viewModel.isBusy {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
            }
            .padding(28)
        } else {
            VStack(spacing: 16) {
                EmptyStateView(title: viewModel.volumes.isEmpty ? "未发现 NTFS 分区" : "请选择一个 NTFS 分区", systemImage: "externaldrive")
                if let error = viewModel.lastError {
                    ErrorPanel(message: error)
                        .padding(.horizontal, 28)
                }
                Text(viewModel.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Header: View {
    let volume: NTFSVolume

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 6) {
                Text(volume.displayName)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(2)
                Text("\(volume.fileSystemName) · \(volume.deviceNode)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct StatusGrid: View {
    let volume: NTFSVolume
    let dependencies: DependencyStatus
    let health: VolumeHealthStatus

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 14) {
            GridRow {
                StatusItem(title: "容量", value: volume.formattedSize, symbol: "internaldrive")
                StatusItem(title: "挂载状态", value: volume.isMounted ? "已挂载" : "未挂载", symbol: "checkmark.circle")
            }
            GridRow {
                StatusItem(title: "当前位置", value: volume.mountPoint ?? "尚未挂载", symbol: "folder")
                StatusItem(title: "写入能力", value: writeStatus, symbol: "pencil.and.outline")
            }
            GridRow {
                StatusItem(title: "Homebrew", value: dependencies.brewPath ?? "未找到", symbol: "cup.and.saucer")
                StatusItem(title: "macFUSE", value: macFUSEStatus, symbol: "puzzlepiece.extension")
            }
            GridRow {
                StatusItem(title: "ntfs-3g", value: dependencies.ntfs3gPath ?? "未找到", symbol: "terminal")
                StatusItem(title: "磁盘状态", value: health.title, symbol: "stethoscope")
            }
        }
    }

    private var macFUSEStatus: String {
        guard dependencies.macFUSEInstalled else { return "未安装" }
        return dependencies.macFUSELoaded ? "已安装并已加载" : "已安装，等待加载/授权"
    }

    private var writeStatus: String {
        if volume.isMounted {
            if volume.isWritable == true { return "系统显示可写" }
            if volume.isReadOnly { return "当前只读" }
            if volume.mountPoint?.hasPrefix("/Volumes/MacNTFSWriter") == true { return "已由 NTFS Writer for Mac 挂载" }
            return "需重新挂载"
        }
        return "可尝试挂载为可写"
    }
}

private struct StatusItem: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActionBar: View {
    @ObservedObject var viewModel: MainViewModel
    let volume: NTFSVolume
    @State private var isShowingForceConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if !viewModel.dependencies.isReady {
                    Button {
                        viewModel.performDependencyAction()
                    } label: {
                        Label(viewModel.dependencyActionTitle, systemImage: viewModel.dependencies.isBrewInstalled ? "terminal" : "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy)
                }

                Button {
                    viewModel.checkSelectedVolumeHealth()
                } label: {
                    Label("检查状态", systemImage: "stethoscope")
                }
                .disabled(viewModel.isBusy || !viewModel.dependencies.isReady)

                Button {
                    viewModel.mountSelectedVolumeReadOnly()
                } label: {
                    Label("只读打开", systemImage: "eye")
                }
                .disabled(viewModel.isBusy || !viewModel.dependencies.isReady)

                Button {
                    viewModel.mountSelectedVolumeWritable()
                } label: {
                    Label("挂载为可写", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy || !viewModel.dependencies.isReady)
            }

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    isShowingForceConfirmation = true
                } label: {
                    Label("强制修复并挂载", systemImage: "wrench.and.screwdriver")
                }
                .disabled(viewModel.isBusy || !viewModel.dependencies.isReady)

                Button {
                    viewModel.unmountSelectedVolume()
                } label: {
                    Label("安全卸载", systemImage: "eject")
                }
                .disabled(viewModel.isBusy || !volume.isMounted)

                Button {
                    viewModel.openSelectedVolume()
                } label: {
                    Label("在 Finder 打开", systemImage: "folder")
                }
                .disabled(viewModel.isBusy || volume.mountPoint == nil)
            }
        }
        .alert("确认强制修复？", isPresented: $isShowingForceConfirmation) {
            Button("确认强制修复", role: .destructive) {
                viewModel.repairAndMountSelectedVolume()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会运行 ntfsfix，并用 remove_hiberfile 尝试清除 Windows 休眠文件。适合你已经确认不需要保留 Windows 休眠状态时使用。")
        }
    }
}

private struct HealthPanel: View {
    let status: VolumeHealthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(status.title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)
            Text(status.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let rawOutput = status.rawOutput {
                DisclosureGroup("原始诊断信息") {
                    Text(rawOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .font(.caption)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var symbol: String {
        switch status.state {
        case .notChecked:
            return "questionmark.circle"
        case .healthy:
            return "checkmark.seal.fill"
        case .windowsHibernated:
            return "moon.zzz.fill"
        case .needsWindowsRepair:
            return "wrench.and.screwdriver.fill"
        case .permissionDenied:
            return "lock.shield.fill"
        case .bitLocker, .unsupported:
            return "externaldrive.badge.xmark"
        case .missingDependency:
            return "puzzlepiece.extension"
        case .unknown:
            return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch status.state {
        case .healthy:
            return .green
        case .windowsHibernated, .needsWindowsRepair, .unknown:
            return .orange
        case .permissionDenied, .bitLocker, .missingDependency, .unsupported:
            return .red
        case .notChecked:
            return .secondary
        }
    }
}

private struct WarningPanel: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("需要注意", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OperationLogPanel: View {
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("最近操作", systemImage: "list.bullet.rectangle")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entries, id: \.self) { entry in
                        Text(entry)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 110)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DependencySummary: View {
    let status: DependencyStatus
    let isBusy: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: status.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(status.isReady ? .green : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.summaryTitle)
                        .font(.headline)
                    Text(status.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }

            if !status.isReady {
                Button(action: action) {
                    Label(actionTitle, systemImage: status.isBrewInstalled ? "terminal" : "safari")
                }
                .controlSize(.small)
                .disabled(isBusy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InstallLogPanel: View {
    let log: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("安装提示", systemImage: "terminal")
                .font(.headline)
            ScrollView {
                Text(log)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SafetyNotes: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("写入前请先在 Windows 正常关机并弹出硬盘。", systemImage: "checkmark.shield")
            Label("如果 Windows 开启快速启动或磁盘休眠，ntfs-3g 可能会拒绝写入。", systemImage: "bolt.slash")
            Label("重要资料建议先备份，再进行跨系统写入。", systemImage: "externaldrive.badge.timemachine")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

private struct ErrorPanel: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("操作失败", systemImage: "xmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
