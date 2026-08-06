import Foundation

/// Russian pluralisation and number formatting, ported from the prototype's `plu` / `numRu`.
enum Ru {
    /// `forms` = [1 штука, 2 штуки, 5 штук]
    static func plural(_ n: Double, _ forms: [String]) -> String {
        guard forms.count == 3 else { return forms.first ?? "" }
        // Fractional values always take the genitive singular: «0,5 порции».
        if n.truncatingRemainder(dividingBy: 1) != 0 { return forms[1] }
        let a = Int(abs(n)) % 100
        let b = a % 10
        if a > 10 && a < 20 { return forms[2] }
        if b == 1 { return forms[0] }
        if b > 1 && b < 5 { return forms[1] }
        return forms[2]
    }

    static func plural(_ n: Int, _ forms: [String]) -> String { plural(Double(n), forms) }

    /// One decimal place, comma separator, no trailing «,0» — «0,5», «2», «1,5».
    static func number(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Thousands separated by a narrow space, as `toLocaleString('ru-RU')` renders them.
    static func grouped(_ value: Int) -> String {
        let s = String(abs(value))
        var out = ""
        for (i, ch) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append("\u{2009}") }
            out.append(ch)
        }
        return (value < 0 ? "-" : "") + String(out.reversed())
    }

    static let shortWeekdays = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
    static let fullWeekdays = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг",
                               "Пятница", "Суббота"]
    static let monthsGenitive = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля",
                                 "августа", "сентября", "октября", "ноября", "декабря"]
    static let monthsNominative = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль",
                                   "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]

    static func positions(_ n: Int) -> String {
        plural(n, ["позицию", "позиции", "позиций"])
    }

    static func days(_ n: Int) -> String {
        plural(n, ["день", "дня", "дней"])
    }

    static func years(_ n: Int) -> String {
        plural(n, ["год", "года", "лет"])
    }
}

// MARK: - Calendar helpers

enum Cal {
    /// A Monday-first Gregorian calendar — the design's week strip and month grid both start on Пн.
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "ru_RU")
        return c
    }()

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static var today: Date { startOfDay(Date()) }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Whole days between two days (positive when `date` is after `from`).
    static func dayOffset(_ date: Date, from: Date = Cal.today) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(date)).day ?? 0
    }

    /// Monday of the week that contains `date`.
    static func startOfWeek(_ date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        let backwards = (weekday + 5) % 7                      // Monday → 0
        return startOfDay(adding(days: -backwards, to: date))
    }

    static func day(_ date: Date) -> Int { calendar.component(.day, from: date) }
    static func month(_ date: Date) -> Int { calendar.component(.month, from: date) - 1 }
    static func year(_ date: Date) -> Int { calendar.component(.year, from: date) }
    static func weekdayIndex(_ date: Date) -> Int { calendar.component(.weekday, from: date) - 1 }

    static func firstOfMonth(year: Int, month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)) ?? Cal.today
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        let first = firstOfMonth(year: year, month: month)
        return calendar.range(of: .day, in: .month, for: first)?.count ?? 30
    }

    static func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month + 1, day: day)) ?? Cal.today
    }

    /// «6 августа»
    static func dayMonth(_ date: Date) -> String {
        "\(day(date)) \(Ru.monthsGenitive[month(date)])"
    }

    /// «Среда, 6 августа»
    static func weekdayDayMonth(_ date: Date) -> String {
        "\(Ru.fullWeekdays[weekdayIndex(date)]), \(dayMonth(date))"
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
