import SwiftUI

/// The home screen: day navigation, calorie + macro progress, meals with their entries.
struct DiaryScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var day: Date { nav.day }
    private var isToday: Bool { Cal.isSameDay(day, Cal.today) }
    private var totals: Nutrition { store.totals(on: day) }
    private var goals: Goals { store.goals }

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

                if !hintText.isEmpty {
                    HStack(spacing: 12) {
                        Text(hintText)
                            .golos(400, 12.5, lineHeight: 1.45)
                            .foregroundStyle(Theme.greenDark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.greenTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.bottom, 22)
                }

                VStack(spacing: 10) {
                    ForEach(MealKind.ordered) { meal in
                        mealCard(meal)
                    }
                }

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
            return ("\(streak) \(Ru.days(streak)) подряд", Theme.greenTint, Theme.greenDark)
        }
        let kcal = store.kcal(on: day)
        if kcal == 0 { return ("Нет записей", Theme.ink(0.05), Theme.ink(0.45)) }
        if kcal > goals.kcal { return ("Превышение", Theme.fatTint, Theme.fatText) }
        return ("В норме", Theme.greenTint, Theme.greenDark)
    }

    // MARK: - Week strip (Mon…Sun of the selected week)

    private var weekStrip: some View {
        let monday = Cal.startOfWeek(day)
        return HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { index in
                let date = Cal.adding(days: index, to: monday)
                let isSelected = Cal.isSameDay(date, day)
                let isFuture = Cal.dayOffset(date) > 0
                let kcal = isFuture ? 0 : store.kcal(on: date)

                Button {
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
                            .fill(dotColour(kcal: kcal, isSelected: isSelected))
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
        }
    }

    private func dotColour(kcal: Int, isSelected: Bool) -> Color {
        guard kcal > 0 else { return .clear }
        if isSelected { return Theme.toastAccent }
        return kcal > goals.kcal ? Theme.fatBar : Theme.green
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

    private var hintText: String {
        guard isToday else { return "" }
        guard goals.protein > 0, goals.kcal > 0 else { return "" }
        let proteinShare = totals.protein / Double(goals.protein)
        let kcalShare = totals.kcal / Double(goals.kcal)
        return proteinShare < kcalShare
            ? "Белка сегодня меньше нормы — добавьте творог или рыбу к ужину."
            : "Белок в норме. Так держать."
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
