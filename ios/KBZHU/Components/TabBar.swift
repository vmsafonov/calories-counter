import SwiftUI

/// Custom bottom bar with the floating «+» — the design's four tabs plus a centred action.
struct TabBar: View {
    let current: Screen
    let onSelect: (Screen) -> Void
    let onAdd: () -> Void

    private struct Item {
        let screen: Screen
        let title: String
        let symbol: String
    }

    private let items: [Item] = [
        Item(screen: .diary, title: "Дневник", symbol: "list.bullet"),
        Item(screen: .stats, title: "Статистика", symbol: "chart.bar.fill"),
        Item(screen: .foods, title: "Продукты", symbol: "fork.knife"),
        Item(screen: .profile, title: "Профиль", symbol: "person.fill")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                ForEach(items, id: \.screen) { item in
                    let isOn = item.screen == current
                    Button {
                        onSelect(item.screen)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 18, weight: .semibold))
                            Text(item.title)
                                .golos(600, 10.5)
                        }
                        .foregroundStyle(isOn ? Theme.green : Theme.ink)
                        .opacity(isOn ? 1 : 0.35)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 10)
            .frame(height: 92, alignment: .top)
            .background(
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay { Color.white.opacity(0.55) }
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.ink(0.08)).frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .bottom)
            )

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Theme.green, in: Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: Theme.green.opacity(0.6), radius: 11, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .offset(y: -12)
        }
        .frame(height: 92, alignment: .top)
    }
}

/// Dark pill that confirms an action — «„Банан" в дневнике · Готово».
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .golos(500, 13.5)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text("Готово")
                .golos(600, 12.5)
                .foregroundStyle(Theme.toastAccent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.45), radius: 14, x: 0, y: 12)
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
