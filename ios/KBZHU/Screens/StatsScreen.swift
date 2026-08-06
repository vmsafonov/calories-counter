import SwiftUI

/// Rolling seven days: calories per day, averages, macro averages.
struct StatsScreen: View {
    @EnvironmentObject private var store: AppStore

    private var days: [Date] {
        (-6...0).map { Cal.adding(days: $0, to: Cal.today) }
    }

    var body: some View {
        let goals = store.goals
        let weekTotal = days
            .map { store.totals(on: $0) }
            .reduce(Nutrition.zero) { $0 + $1 }
        let average = Nutrition(kcal: weekTotal.kcal / 7, protein: weekTotal.protein / 7,
                                fat: weekTotal.fat / 7, carbs: weekTotal.carbs / 7)
        let inNorm = days.filter { day in
            let kcal = store.kcal(on: day)
            return kcal > 0 && kcal <= goals.kcal
        }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Неделя")
                    .golos(700, 24)
                    .kerning(-0.24)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 4)
                Text("\(Cal.dayMonth(days[0])) — \(Cal.dayMonth(days[6]))")
                    .golos(400, 13)
                    .foregroundStyle(Theme.ink(0.45))
                    .padding(.bottom, 24)

                chartCard(goalKcal: goals.kcal)
                    .padding(.bottom, 14)

                HStack(spacing: 10) {
                    statTile(value: Ru.grouped(Int(average.kcal.rounded())),
                             caption: "средние ккал в день")
                    statTile(value: "\(inNorm) из 7", caption: "дней в пределах нормы")
                }
                .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Среднее по нутриентам")
                        .golos(600, 14)
                        .foregroundStyle(Theme.ink)
                        .padding(.bottom, 16)

                    VStack(spacing: 13) {
                        averageRow(name: "Белки", value: average.protein,
                                   goal: goals.protein, color: Theme.proteinBar)
                        averageRow(name: "Жиры", value: average.fat,
                                   goal: goals.fat, color: Theme.fatBar)
                        averageRow(name: "Углеводы", value: average.carbs,
                                   goal: goals.carbs, color: Theme.carbBar)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.hairlineStrong, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 108)
        }
    }

    private func chartCard(goalKcal: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let kcal = store.kcal(on: day)
                    VStack(spacing: 8) {
                        Text(kcal > 0 ? Ru.grouped(kcal) : "—")
                            .golos(600, 10.5)
                            .tabularNumbers()
                            .foregroundStyle(Theme.ink(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(kcal > goalKcal ? Theme.fatBar : Theme.green)
                            .frame(height: barHeight(kcal))
                        Text(Ru.shortWeekdays[Cal.weekdayIndex(day)])
                            .golos(500, 11)
                            .foregroundStyle(Theme.ink(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
            .padding(.bottom, 12)

            HStack(spacing: 14) {
                legend(color: Theme.green, title: "в норме")
                legend(color: Theme.fatBar, title: "превышение")
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.ink(0.08)).frame(height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// Same scale as the prototype: full height at 2200 kcal, never thinner than 6 pt.
    private func barHeight(_ kcal: Int) -> CGFloat {
        max(6, min(108, CGFloat(kcal) / 2200 * 108))
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .golos(400, 11.5)
                .foregroundStyle(Theme.ink(0.45))
        }
    }

    private func statTile(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .golos(700, 22)
                .tabularNumbers()
                .foregroundStyle(Theme.ink)
            Text(caption)
                .golos(400, 11.5, lineHeight: 1.3)
                .foregroundStyle(Theme.ink(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.hairlineStrong, lineWidth: 1)
        )
    }

    private func averageRow(name: String, value: Double, goal: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .golos(500, 12.5)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text("\(Int(value.rounded())) / \(goal) г")
                    .golos(400, 12)
                    .tabularNumbers()
                    .foregroundStyle(Theme.ink(0.45))
            }
            ProgressBar(progress: goal > 0 ? value / Double(goal) : 0, color: color)
        }
    }
}
