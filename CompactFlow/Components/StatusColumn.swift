import SwiftUI

struct StatusColumn: View {
    let status: TaskStatus
    @ObservedObject var viewModel: TaskBoardViewModel
    @State private var confirmingClear = false
    @State private var targetedIndex: Int?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var selectionOrigin: CGPoint?
    @State private var selectionPoint: CGPoint?
    @State private var selectionBase: Set<UUID> = []
    @State private var isMarqueeSelecting = false

    private var items: [TaskItem] { viewModel.tasks(in: status) }

    var body: some View {
        VStack(spacing: 8) {
            header
            if status == .todo { AddTaskField(viewModel: viewModel) }

            ZStack(alignment: .topLeading) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                    if items.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: emptyIcon)
                                .font(.system(size: 18, weight: .light))
                            Text(emptyText)
                                .font(.system(size: 11))
                        }
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 34)
                            .dropDestination(for: String.self) { payloads, _ in
                                move(payloads.first, to: 0)
                            } isTargeted: { targeted in
                                targetedIndex = targeted ? 0 : nil
                            }
                    }

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                        DropSlot(active: targetedIndex == index, color: accent)
                        TaskCard(task: task, viewModel: viewModel)
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: TaskCardFramePreferenceKey.self,
                                        value: [task.id: proxy.frame(in: .named(coordinateSpaceName))]
                                    )
                                }
                            }
                            .dropDestination(for: String.self) { payloads, _ in
                                move(payloads.first, to: index)
                            } isTargeted: { targeted in
                                targetedIndex = targeted ? index : nil
                            }
                    }

                    DropSlot(active: targetedIndex == items.count, color: accent)
                        .dropDestination(for: String.self) { payloads, _ in
                            move(payloads.first, to: items.count)
                        } isTargeted: { targeted in
                            targetedIndex = targeted ? items.count : nil
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                }
                .coordinateSpace(name: coordinateSpaceName)
                .onPreferenceChange(TaskCardFramePreferenceKey.self) { cardFrames = $0 }
                .simultaneousGesture(marqueeGesture)

                if let rectangle = selectionRectangle, isMarqueeSelecting {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(Rectangle().stroke(Color.accentColor.opacity(0.8), lineWidth: 1))
                        .frame(width: rectangle.width, height: rectangle.height)
                        .offset(x: rectangle.minX, y: rectangle.minY)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { payloads, _ in
                move(payloads.first, to: items.count)
            }
        }
        .padding(10)
        .background(columnBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.55)))
        .confirmationDialog("Clear all completed tasks?", isPresented: $confirmingClear) {
            Button("Clear Done", role: .destructive) { viewModel.clearDone() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Circle().fill(accent).frame(width: 6, height: 6)
            Text(status.title).font(.system(size: 12, weight: .semibold))
            Text("\(items.count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
            if status == .done && !items.isEmpty {
                Button { confirmingClear = true } label: {
                    Image(systemName: "trash").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear Done")
            }
        }
        .frame(height: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title), \(items.count) tasks")
    }

    private var accent: Color {
        switch status { case .todo: .gray; case .processing: .orange; case .done: .green }
    }

    private var emptyText: String {
        switch status { case .todo: "Nothing waiting"; case .processing: "Ready when you are"; case .done: "Completed tasks appear here" }
    }

    private var emptyIcon: String {
        switch status { case .todo: "tray"; case .processing: "hourglass"; case .done: "checkmark.circle" }
    }

    private var columnBackground: Color {
        status == .processing
            ? Color.orange.opacity(0.035)
            : Color(nsColor: .controlBackgroundColor).opacity(0.42)
    }

    private var coordinateSpaceName: String { "task-column-\(status.rawValue)" }

    private var selectionRectangle: CGRect? {
        guard let origin = selectionOrigin, let point = selectionPoint else { return nil }
        return CGRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(point.x - origin.x),
            height: abs(point.y - origin.y)
        )
    }

    private var marqueeGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                if selectionOrigin == nil {
                    // Card-originated drags remain task drags. Marquee selection only
                    // begins in the column's empty space.
                    guard !cardFrames.values.contains(where: { $0.contains(value.startLocation) }) else { return }
                    selectionOrigin = value.startLocation
                    selectionBase = NSEvent.modifierFlags.intersection([.command, .shift]).isEmpty
                        ? [] : viewModel.selectedTaskIDs
                    isMarqueeSelecting = true
                }
                guard isMarqueeSelecting else { return }
                selectionPoint = value.location
                guard let rectangle = selectionRectangle else { return }
                let hits = Set(cardFrames.compactMap { id, frame in frame.intersects(rectangle) ? id : nil })
                viewModel.select(selectionBase.union(hits), extending: false)
            }
            .onEnded { _ in
                selectionOrigin = nil
                selectionPoint = nil
                selectionBase = []
                isMarqueeSelecting = false
            }
    }

    private func move(_ payload: String?, to index: Int) -> Bool {
        guard let payload else { return false }
        let ids = payload.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        guard let id = ids.first else { return false }
        let sourceIndex = ids.count == 1 ? items.firstIndex(where: { $0.id == id }) : nil
        let destination: Int
        if let sourceIndex, sourceIndex < index, index < items.count {
            // Dropping over a lower card means placing the dragged card after it.
            destination = index + 1
        } else {
            destination = index
        }
        withAnimation(.snappy(duration: 0.2)) {
            viewModel.moveTasks(ids: ids, to: status, at: destination)
        }
        targetedIndex = nil
        return true
    }
}

private struct TaskCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct DropSlot: View {
    let active: Bool
    let color: Color

    var body: some View {
        Capsule()
            .fill(color.opacity(active ? 0.95 : 0))
            .frame(height: 3)
            .padding(.vertical, 3)
            .animation(.easeOut(duration: 0.12), value: active)
    }
}
