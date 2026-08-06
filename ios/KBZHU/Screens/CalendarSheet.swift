import SwiftUI

/// Bottom sheet for jumping to any past day. Dots repeat the week strip's status colours.
struct CalendarSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var canGoForward: Bool {
        let today = Cal.today
        return nav.calendarYear < Cal.year(today)
            || (nav.calendarYear == Cal.year(today) && nav.calendarMonth < Cal.month(today))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x141715, opacity: 0.4)
                .ignoresSafeArea()
                .onTapGesture { nav.calendarOpen = false }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Theme.ink(0.15))
                    .frame(width: 38, height: 4)
                    .padding(.bottom, 18)

                HStack {
                    monthButton(symbol: "chevron.left", enabled: true) {
                        if nav.calendarMonth == 0 {
                            nav.calendarMonth = 11
                            nav.calendarYear -= 1
                        } else {
                            nav.calendarMonth -= 1
                        }
                    }
                    Spacer(minLength: 0)
                    Text("\(Ru.monthsNominative[nav.calendarMonth]) \(String(nav.calendarYear))")
                        .golos(600, 16)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    monthButton(symbol: "chevron.right", enabled: canGoForward) {
                        guard canGoForward else { return }
                        if nav.calendarMonth == 11 {
                            nav.calendarMonth = 0
                            nav.calendarYear += 1
                        } else {
                            nav.calendarMonth += 1
                        }
                    }
                }
                .padding(.bottom, 18)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(["пн", "вт", "ср", "чт", "пт", "сб", "вс"], id: \.self) { title in
                        Text(title)
                            .golos(500, 10.5)
                            .foregroundStyle(Theme.ink(0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 6)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(cells) { cell in
                        dayCell(cell)
                    }
                }

                Button {
                    nav.day = Cal.today
                    nav.calendarMonth = Cal.month(Cal.today)
                    nav.calendarYear = Cal.year(Cal.today)
                    nav.calendarOpen = false
                } label: {
                    Text("Сегодня")
                        .golos(600, 14)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.ink(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 30)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 0, topTrailingRadius: 30,
                                       style: .continuous)
                    .fill(Color.white)
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom))
        }
    }

    private func monthButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(enabled ? Theme.ink : Theme.ink(0.25))
                .frame(width: 44, height: 44)
                .background(Theme.ink(enabled ? 0.05 : 0.02),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Grid

    private struct Cell: Identifiable {
        let id: Int
        let date: Date?
    }

    private var cells: [Cell] {
        let first = Cal.firstOfMonth(year: nav.calendarYear, month: nav.calendarMonth)
        let leading = (Cal.weekdayIndex(first) + 6) % 7 // Monday-first offset
        let count = Cal.daysInMonth(year: nav.calendarYear, month: nav.calendarMonth)
        var result: [Cell] = (0..<leading).map { Cell(id: -($0 + 1), date: nil) }
        for day in 1...count {
            let date = Cal.date(year: nav.calendarYear, month: nav.calendarMonth, day: day)
            result.append(Cell(id: day, date: date))
        }
        return result
    }

    @ViewBuilder
    private func dayCell(_ cell: Cell) -> some View {
        if let date = cell.date {
            let isSelected = Cal.isSameDay(date, nav.day)
            let isFuture = Cal.dayOffset(date) > 0
            let kcal = isFuture ? 0 : store.kcal(on: date)

            Button {
                guard !isFuture else { return }
                nav.day = Cal.startOfDay(date)
                nav.openSwipeEntryID = nil
                nav.calendarOpen = false
            } label: {
                VStack(spacing: 4) {
                    Text("\(Cal.day(date))")
                        .golos(600, 13.5)
                        .tabularNumbers()
                        .foregroundStyle(isSelected ? Color.white : Theme.ink)
                    Circle()
                        .fill(kcal == 0 ? Color.clear
                              : (isSelected ? Theme.toastAccent
                                 : (kcal > store.goals.kcal ? Theme.fatBar : Theme.green)))
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isSelected ? Theme.ink : (kcal > 0 ? Theme.ink(0.04) : Color.clear),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .opacity(isFuture ? 0.28 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
        } else {
            Color.clear.frame(height: 46)
        }
    }
}
