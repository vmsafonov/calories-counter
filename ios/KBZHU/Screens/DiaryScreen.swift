import SwiftUI

/// The home screen: day navigation, calorie + macro progress, meals with their entries.
struct DiaryScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var day: Date { nav.day }
    private var isToday: Bool { Cal.isSameDay(day, Cal.today) }
    private var totals: Nutrition { store.totals(on: day) }
    /// Норма именно этого дня: прошлые дни считаются по норме тех дат.
    private var goals: Goals { store.goals(on: day) }

    private var eaten: Int { Int(totals.kcal.rounded()) }
    private var left: Int { max(0, goals.kcal - eaten) }
    private var over: Int { max(0, eaten - goals.kcal) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 16)

                weekStrip
                    .padding(.bottom, 20)

                calorieCard
                    .padding(.bottom, 14)

                Color.clear.frame(height: 22)

                VStack(spacing: 10) {
                    ForEach(MealKind.ordered) { meal in
                        mealCard(meal)
                    }
                }

                // Only offered when the previous day actually has something to copy.
                if store.hasEntries(on: Cal.adding(days: -1, to: day)) {
                    Button {
                        nav.go(.repeatDay)
                    } label: {
                        Text("Повторить вчерашний день")
                            .golos(500, 13.5)
                            .foregroundStyle(Theme.ink(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                    .foregroundStyle(Theme.ink(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 108)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                nav.calendarMonth = Cal.month(day)
                nav.calendarYear = Cal.year(day)
                nav.calendarOpen = true
            } label: {
                HStack(spacing: 9) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayTitle)
                            .golos(700, 24)
                            .kerning(-0.24)
                            .foregroundStyle(Theme.ink)
                        Text(Cal.weekdayDayMonth(day))
                            .golos(400, 13)
                            .foregroundStyle(Theme.ink(0.45))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink(0.55))
                        .frame(width: 26, height: 26)
                        .background(Theme.ink(0.06), in: Circle())
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text(badge.title)
                .golos(600, 12.5)
                .foregroundStyle(badge.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(badge.background, in: Capsule())
        }
    }

    private var dayTitle: String {
        if isToday { return "Сегодня" }
        if Cal.isSameDay(day, Cal.adding(days: -1, to: Cal.today)) { return "Вчера" }
        return Cal.dayMonth(day)
    }

    private var badge: (title: String, background: Color, foreground: Color) {
        if isToday {
            let streak = store.streakDays
            guard streak > 0 else {
                return ("Нет записей", Theme.ink(0.05), Theme.ink(0.45))
            }
            return ("\(streak) \(Ru.days(streak)) подряд", Theme.greenTint, Theme.greenDark)
        }
        let status = DayStatus(kcal: store.kcal(on: day), goal: goals.kcal)
        return (status.title, status.badgeBackground, status.badgeForeground)
    }

    // MARK: - Week strip (Mon…Sun of the selected week)

    private var weekStrip: some View {
        let monday = Cal.startOfWeek(day)
        let nextWeekAvailable = Cal.dayOffset(Cal.adding(days: 7, to: monday)) <= 0

        return HStack(spacing: 2) {
            weekArrow(symbol: "chevron.left", enabled: true) {
                nav.day = Cal.adding(days: -7, to: monday)
                nav.openSwipeEntryID = nil
            }

            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    let date = Cal.adding(days: index, to: monday)
                    dayCell(date)
                }
            }
            .frame(maxWidth: .infinity)

            weekArrow(symbol: "chevron.right", enabled: nextWeekAvailable) {
                guard nextWeekAvailable else { return }
                let next = Cal.adding(days: 7, to: monday)
                nav.day = Cal.dayOffset(next) > 0 ? Cal.today : next
                nav.openSwipeEntryID = nil
            }
        }
    }

    private func weekArrow(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(enabled ? Theme.ink(0.4) : Theme.ink(0.16))
                .frame(width: 26, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = Cal.isSameDay(date, day)
        let isFuture = Cal.dayOffset(date) > 0
        let kcal = isFuture ? 0 : store.kcal(on: date)
        let dayGoal = store.goals(on: date).kcal

        return Button {
            guard !isFuture else { return }
            nav.day = Cal.startOfDay(date)
            nav.openSwipeEntryID = nil
        } label: {
            VStack(spacing: 7) {
                Text(Ru.shortWeekdays[Cal.weekdayIndex(date)])
                    .golos(500, 10.5)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.55)
                                     : (isFuture ? Theme.ink(0.22) : Theme.ink(0.38)))
                Text("\(Cal.day(date))")
                    .golos(600, 14.5)
                    .tabularNumbers()
                    .foregroundStyle(isSelected ? Color.white
                                     : (isFuture ? Theme.ink(0.28) : Theme.ink))
                Circle()
                    .fill(dotColour(kcal: kcal, goal: dayGoal, isSelected: isSelected))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? Theme.ink : Color.clear,
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func dotColour(kcal: Int, goal: Int, isSelected: Bool) -> Color {
        guard kcal > 0 else { return .clear }
        if isSelected { return Theme.toastAccent }
        return DayStatus(kcal: kcal, goal: goal).markColor
    }

    // MARK: - Calories + macros

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kcalCaption)
                        .golos(500, 12.5)
                        .foregroundStyle(Theme.ink(0.5))
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(kcalBig)
                            .golos(800, 46)
                            .kerning(-1.38)
                            .tabularNumbers()
                            .foregroundStyle(over > 0 ? Theme.overText : Theme.ink)
                        Text("ккал")
                            .golos(500, 15)
                            .foregroundStyle(Theme.ink(0.45))
                    }
                }
                .contentShape(Rectangle())
                // Tap flips the big number between «осталось» and «съедено».
                .onTapGesture { store.setShowRemaining(!store.showRemaining) }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("цель")
                        .golos(400, 12)
                        .foregroundStyle(Theme.ink(0.45))
                    Text(Ru.grouped(goals.kcal))
                        .golos(600, 12)
                        .tabularNumbers()
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.bottom, 18)

            ProgressBar(progress: goals.kcal > 0 ? totals.kcal / Double(goals.kcal) : 0,
                        color: over > 0 ? Theme.fatBar : Theme.green,
                        height: 10)

            VStack(spacing: 14) {
                MacroRow(name: "Белки", value: totals.protein, goal: goals.protein, color: Theme.proteinBar)
                MacroRow(name: "Жиры", value: totals.fat, goal: goals.fat, color: Theme.fatBar)
                MacroRow(name: "Углеводы", value: totals.carbs, goal: goals.carbs, color: Theme.carbBar)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var kcalCaption: String {
        if over > 0 { return "Превышение нормы" }
        if isToday { return store.showRemaining ? "Осталось на сегодня" : "Съедено сегодня" }
        return store.showRemaining ? "Осталось в этот день" : "Съедено в этот день"
    }

    private var kcalBig: String {
        if over > 0 { return "+" + Ru.grouped(over) }
        return Ru.grouped(store.showRemaining ? left : eaten)
    }

    // MARK: - Meals

    private func mealCard(_ meal: MealKind) -> some View {
        let entries = store.entries(on: day, meal: meal)
        let mealTotals = store.totals(on: day, meal: meal)
        let kcal = Int(mealTotals.kcal.rounded())

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(meal.title)
                        .golos(600, 15)
                        .foregroundStyle(Theme.ink)
                    Text(entries.first.map { Cal.time($0.createdAt) } ?? "—")
                        .golos(400, 12)
                        .foregroundStyle(Theme.ink(0.38))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(kcal > 0 ? "\(kcal) ккал" : "пусто")
                        .golos(600, 13.5)
                        .tabularNumbers()
                        .foregroundStyle(Theme.ink(0.55))
                    if kcal > 0 {
                        Text(mealTotals.macroLine)
                            .golos(400, 11)
                            .tabularNumbers()
                            .foregroundStyle(Theme.ink(0.38))
                    }
                }
            }
            .padding(.bottom, entries.isEmpty ? 2 : 14)

            VStack(spacing: 9) {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }

            Button {
                nav.openAdd(meal: meal)
            } label: {
                Text("+ Добавить")
                    .golos(600, 13.5)
                    .foregroundStyle(Theme.greenDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.hairlineStrong, lineWidth: 1)
        )
    }

    private func entryRow(_ entry: Entry) -> some View {
        let food = store.food(entry.foodID)
        let nutrition = store.nutrition(of: entry)

        return SwipeToDeleteRow(
            isOpen: nav.openSwipeEntryID == entry.id,
            onOpen: { nav.openSwipeEntryID = entry.id },
            onClose: { if nav.openSwipeEntryID == entry.id { nav.openSwipeEntryID = nil } },
            onDelete: {
                let name = food?.name ?? "Запись"
                store.delete(entryID: entry.id)
                nav.openSwipeEntryID = nil
                nav.flash("«\(name)» удалено")
            },
            onTap: {
                guard let food else { return }
                nav.openEntry(entry, food: food)
            }
        ) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food?.name ?? "Продукт удалён")
                        .golos(500, 13.5)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(Ru.number(entry.grams)) г · Б \(Int(nutrition.protein.rounded())) Ж \(Int(nutrition.fat.rounded())) У \(Int(nutrition.carbs.rounded()))")
                        .golos(400, 11.5)
                        .foregroundStyle(Theme.ink(0.42))
                }
                Spacer(minLength: 6)
                Text("\(Int(nutrition.kcal.rounded())) ккал")
                    .golos(500, 13)
                    .tabularNumbers()
                    .foregroundStyle(Theme.ink(0.55))
            }
        }
        .padding(.horizontal, -4)
    }
}
