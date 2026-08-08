import SwiftUI

/// Неделя Пн–Вс: калории по дням, средние и средние нутриенты.
/// Неделя та же, что выбрана в дневнике, — переключается стрелками здесь или там.
struct StatsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var monday: Date { Cal.startOfWeek(nav.day) }
    private var weekDays: [Date] { (0..<7).map { Cal.adding(days: $0, to: monday) } }
    /// Дни недели, в которые что-то записано: по ним считаются средние.
    private var loggedDays: [Date] { weekDays.filter { store.kcal(on: $0) > 0 } }
    private var nextWeekAvailable: Bool { Cal.dayOffset(Cal.adding(days: 7, to: monday)) <= 0 }

    var body: some View {
        let goals = store.goals
        let logged = loggedDays
        let divisor = Double(max(1, logged.count))
        let sum = logged.map { store.totals(on: $0) }.reduce(Nutrition.zero) { $0 + $1 }
        let average = Nutrition(kcal: sum.kcal / divisor, protein: sum.protein / divisor,
                                fat: sum.fat / divisor, carbs: sum.carbs / divisor)
        let inNorm = logged.filter { DayStatus(kcal: store.kcal(on: $0), goal: goals.kcal) == .onTarget }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 24)

                chartCard(goalKcal: goals.kcal)
                    .padding(.bottom, 14)

                HStack(spacing: 10) {
                    statTile(value: logged.isEmpty ? "—" : Ru.grouped(Int(average.kcal.rounded())),
                             caption: "средние ккал в день")
                    statTile(value: "\(inNorm) из \(logged.count)",
                             caption: "дней в пределах нормы")
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

    // MARK: - Шапка с переключением недель

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Неделя")
                    .golos(700, 24)
                    .kerning(-0.24)
                    .foregroundStyle(Theme.ink)
                Text("\(Cal.dayMonth(monday)) — \(Cal.dayMonth(Cal.adding(days: 6, to: monday)))")
                    .golos(400, 13)
                    .foregroundStyle(Theme.ink(0.45))
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                weekButton(symbol: "chevron.left", enabled: true) {
                    nav.day = Cal.adding(days: -7, to: monday)
                }
                weekButton(symbol: "chevron.right", enabled: nextWeekAvailable) {
                    guard nextWeekAvailable else { return }
                    let next = Cal.adding(days: 7, to: monday)
                    nav.day = Cal.dayOffset(next) > 0 ? Cal.today : next
                }
            }
        }
    }

    private func weekButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(enabled ? Theme.ink : Theme.ink(0.25))
                .frame(width: 40, height: 40)
                .background(Theme.ink(enabled ? 0.05 : 0.02),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - График

    private func chartCard(goalKcal: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    let isFuture = Cal.dayOffset(day) > 0
                    let kcal = isFuture ? 0 : store.kcal(on: day)
                    VStack(spacing: 8) {
                        Text(kcal > 0 ? Ru.grouped(kcal) : " ")
                            .golos(600, 10.5)
                            .tabularNumbers()
                            .foregroundStyle(Theme.ink(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(DayStatus(kcal: kcal, goal: goalKcal).markColor)
                            .frame(height: barHeight(kcal))
                        Text(Ru.shortWeekdays[Cal.weekdayIndex(day)])
                            .golos(500, 11)
                            .foregroundStyle(Theme.ink(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isFuture ? 0.4 : 1)
                }
            }
            .frame(height: 150, alignment: .bottom)
            .padding(.bottom, 12)

            HStack(spacing: 14) {
                legend(color: Theme.green, title: "в норме")
                legend(color: Theme.proteinBar, title: "ниже нормы")
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

    /// Та же шкала, что в прототипе: полная высота на 2200 ккал, тоньше 6 pt не бывает.
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
