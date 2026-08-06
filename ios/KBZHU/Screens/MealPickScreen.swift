import SwiftUI

/// Reached from the big «+» — pick the meal first, then the food.
struct MealPickScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavBar(title: "Куда добавить?") { nav.go(.diary) }
                    .padding(.bottom, 8)

                Text(Cal.weekdayDayMonth(nav.day))
                    .golos(400, 12.5, lineHeight: 1.5)
                    .foregroundStyle(Theme.ink(0.45))
                    .padding(.leading, 34)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(MealKind.ordered) { meal in
                        let kcal = Int(store.totals(on: nav.day, meal: meal).kcal.rounded())
                        Button {
                            nav.openAdd(meal: meal)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(meal.title)
                                        .golos(600, 16)
                                        .foregroundStyle(Theme.ink)
                                    Text(kcal > 0 ? "\(kcal) ккал уже записано" : "пока пусто")
                                        .golos(400, 12)
                                        .foregroundStyle(Theme.ink(0.42))
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Theme.ink(0.3))
                            }
                            .padding(20)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Theme.hairlineStrong, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
    }
}
