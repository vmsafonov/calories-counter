import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    @State private var name: String = ""

    var body: some View {
        let goals = store.goals

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Профиль")
                    .golos(700, 24)
                    .kerning(-0.24)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 22)

                HStack(spacing: 14) {
                    Text(store.initials)
                        .golos(700, 20)
                        .foregroundStyle(Theme.greenDark)
                        .frame(width: 58, height: 58)
                        .background(Theme.greenTint, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        TextField("Ваше имя", text: $name)
                            .golos(600, 17)
                            .foregroundStyle(Theme.ink)
                            .textFieldStyle(.plain)
                            .frame(height: 34)
                            .onChange(of: name) { _, newValue in
                                store.setUserName(newValue)
                            }
                        Text(store.goal.profileSubtitle)
                            .golos(400, 12.5)
                            .foregroundStyle(Theme.ink(0.45))
                    }
                }
                .padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Дневная норма")
                            .golos(600, 14)
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                        Button {
                            nav.go(.norm)
                        } label: {
                            Text("Изменить")
                                .golos(600, 12.5)
                                .foregroundStyle(Theme.greenDark)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 16)

                    HStack(spacing: 8) {
                        normTile(value: Ru.grouped(goals.kcal), caption: "ккал",
                                 color: Theme.ink, flex: 1.2)
                        normTile(value: "\(goals.protein)", caption: "Б", color: Theme.proteinText)
                        normTile(value: "\(goals.fat)", caption: "Ж", color: Theme.fatText)
                        normTile(value: "\(goals.carbs)", caption: "У", color: Theme.carbText)
                    }
                }
                .padding(20)
                .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.bottom, 14)

                VStack(spacing: 0) {
                    profileRow(label: "Цель", value: store.goal.title,
                               action: { nav.go(.bodyGoal) })
                    profileRow(label: "Параметры", value: store.bodyProfile.summary,
                               action: { nav.go(.bodyGoal) })
                    profileRow(label: "Активность", value: store.bodyProfile.activity.title,
                               action: { nav.go(.bodyGoal) })
                    profileRow(label: "Единицы", value: "Граммы, ккал", showsChevron: false, action: nil)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 108)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { name = store.userName }
    }

    private func normTile(value: String, caption: String, color: Color, flex: CGFloat = 1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .golos(700, 18)
                .tabularNumbers()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .golos(400, 11)
                .foregroundStyle(Theme.ink(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(Double(flex))
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func profileRow(label: String, value: String,
                            showsChevron: Bool = true, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(label)
                        .golos(500, 14.5)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    Text(value)
                        .golos(400, 13.5)
                        .foregroundStyle(Theme.ink(0.42))
                        .multilineTextAlignment(.trailing)
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Theme.ink(0.3))
                    }
                }
                .padding(.vertical, 8)
                .frame(minHeight: 52)

                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
