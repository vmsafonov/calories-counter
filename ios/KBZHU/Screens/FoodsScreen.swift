import SwiftUI

/// «Продукты» — the whole food base, editable. Corrections stick and apply to future entries.
struct FoodsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Продукты")
                    .golos(700, 24)
                    .kerning(-0.24)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 4)
                Text("Тап по продукту — исправить вес порции и КБЖУ")
                    .golos(400, 13)
                    .foregroundStyle(Theme.ink(0.45))
                    .padding(.bottom, 20)

                Button {
                    nav.openOwnDishForm()
                } label: {
                    HStack(spacing: 12) {
                        Text("+")
                            .golos(400, 20)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Theme.green, in: Circle())
                        Text("Создать своё блюдо")
                            .golos(600, 14)
                            .foregroundStyle(Theme.greenDark)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(Theme.greenTintSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(Theme.green.opacity(0.45))
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 22)

                SectionCaption(text: "Своя еда")
                    .padding(.bottom, 12)

                if store.ownFoods.isEmpty {
                    Text("Пока пусто — создайте первое блюдо.")
                        .golos(400, 12.5)
                        .foregroundStyle(Theme.ink(0.42))
                        .padding(.bottom, 26)
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.ownFoods) { food in
                            ownRow(food)
                        }
                    }
                    .padding(.bottom, 26)
                }

                SectionCaption(text: "База продуктов")
                    .padding(.bottom, 12)

                VStack(spacing: 0) {
                    ForEach(store.baseFoods) { food in
                        baseRow(food)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 108)
        }
    }

    private func startEditing(_ food: Food) {
        nav.openEditForm(food)
    }

    private func ownRow(_ food: Food) -> some View {
        Button {
            startEditing(food)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .golos(500, 14.5)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(food.listSubtitle)
                        .golos(400, 11.5)
                        .foregroundStyle(Theme.ink(0.42))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Text(food.isEdited ? "изменено" : "своё")
                    .golos(600, 10.5)
                    .foregroundStyle(food.isEdited ? Theme.fatText : Theme.greenDark)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(food.isEdited ? Theme.fatTint : Theme.greenTint,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func baseRow(_ food: Food) -> some View {
        Button {
            startEditing(food)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .golos(500, 14.5)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(food.listSubtitle)
                            .golos(400, 11.5)
                            .foregroundStyle(Theme.ink(0.42))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    if food.isEdited {
                        Text("изменено")
                            .golos(600, 10.5)
                            .foregroundStyle(Theme.fatText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.fatTint,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.vertical, 13)

                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
