import SwiftUI

/// A diary row that slides to the left to reveal «Удалить», as requested in the design chat:
/// no permanent ×, one open row at a time, releasing before the halfway point snaps back.
struct SwipeToDeleteRow<Content: View>: View {
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    let content: () -> Content

    init(isOpen: Bool,
         onOpen: @escaping () -> Void,
         onClose: @escaping () -> Void,
         onDelete: @escaping () -> Void,
         onTap: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.isOpen = isOpen
        self.onOpen = onOpen
        self.onClose = onClose
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content
    }

    @State private var drag: CGFloat = 0
    /// Latches once per gesture so a vertical scroll is never stolen by the row.
    @State private var isHorizontalDrag: Bool?

    private let revealWidth: CGFloat = 88

    private var base: CGFloat { isOpen ? -revealWidth : 0 }

    var body: some View {
        ZStack(alignment: .trailing) {
            Theme.danger
                .overlay(alignment: .trailing) {
                    Button(action: onDelete) {
                        Text("Удалить")
                            .golos(600, 12.5)
                            .foregroundStyle(.white)
                            .frame(width: revealWidth)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

            content()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .offset(x: base + drag)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isOpen { onClose() } else { onTap() }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            if isHorizontalDrag == nil {
                                isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                            }
                            guard isHorizontalDrag == true else { return }
                            let x = min(0, max(-revealWidth, base + value.translation.width))
                            drag = x - base
                        }
                        .onEnded { value in
                            let wasHorizontal = isHorizontalDrag == true
                            isHorizontalDrag = nil
                            guard wasHorizontal else {
                                drag = 0
                                return
                            }
                            let x = min(0, max(-revealWidth, base + value.translation.width))
                            drag = 0
                            if x < -revealWidth / 2 { onOpen() } else { onClose() }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: isOpen)
        .animation(.easeOut(duration: 0.12), value: drag)
    }
}
