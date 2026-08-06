import SwiftUI

/// «Повторить вчерашний день» — copy the whole previous day, or single dishes from it.
struct RepeatScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var previousDay: Date { Cal.adding(days: -1, to: nav.day) }

    var body: some View {
        let entries = store.entries(on: previousDay)
        let totals = store.totals(on: previousDay)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavBar(title: Cal.isSameDay(nav.day, Cal.today) ? "Вчерашний день" : "Предыдущий день") {
                    nav.go(.diary)
                }
                .padding(.bottom, 8)

                Text(entries.isEmpty
                     ? "В этот день записей не было"
                     : "\(Int(totals.kcal.rounded())) ккал · Б \(Int(totals.protein.rounded())) · Ж \(Int(totals.fat.rounded())) · У \(Int(totals.carbs.rounded()))")
                    .golos(400, 12.5, lineHeight: 1.5)
                    .foregroundStyle(Theme.ink(0.45))
                    .padding(.leading, 34)
                    .padding(.bottom, 18)

                if !entries.isEmpty {
                    PrimaryButton(title: "Повторить весь день", height: 54, fontSize: 15) {
                        store.copyDay(from: previousDay, to: nav.day)
                        nav.go(.diary)
                        nav.flash("День скопирован в дневник")
                    }
                    .padding(.bottom, 20)
                }

                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        row(entry)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 108)
        }
    }

    private func row(_ entry: Entry) -> some View {
        let food = store.food(entry.foodID)
        let kcal = Int(store.nutrition(of: entry).kcal.rounded())

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food?.name ?? "Продукт удалён")
                    .golos(500, 14.5)
                    .foregroundStyle(Theme.ink)
                Text("\(entry.meal.title) · \(Ru.number(entry.grams)) г · \(kcal) ккал")
                    .golos(400, 12)
                    .foregroundStyle(Theme.ink(0.42))
            }
            Spacer(minLength: 0)
            Button {
                guard let food else { return }
                store.addEntry(foodID: food.id, meal: entry.meal, grams: entry.grams, day: nav.day)
                nav.flash("«\(food.name)» добавлено")
            } label: {
                Text("+")
                    .golos(600, 19)
                    .foregroundStyle(Theme.greenDark)
                    .frame(width: 40, height: 40)
                    .background(Theme.greenTint, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairlineStrong, lineWidth: 1)
        )
    }
}
