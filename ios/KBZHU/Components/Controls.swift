import SwiftUI
import UIKit

// MARK: - Buttons

/// The big green call-to-action used at the bottom of most screens.
struct PrimaryButton: View {
    let title: String
    var height: CGFloat = 56
    var fontSize: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .golos(600, fontSize)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.green.opacity(0.55), radius: 9, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

/// Outlined secondary button — «Готово», «Пересчитать по параметрам».
struct SecondaryButton: View {
    let title: String
    var height: CGFloat = 56
    var fontSize: CGFloat = 15
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .golos(500, fontSize)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.ink(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Pill chip — add-screen tabs, sex / activity / goal selectors.
struct Chip: View {
    let title: String
    let isOn: Bool
    var height: CGFloat? = nil
    var horizontalPadding: CGFloat = 14
    var cornerRadius: CGFloat = 99
    var fontSize: CGFloat = 12.5
    var fillsWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .golos(600, fontSize)
                .foregroundStyle(isOn ? Color.white : Theme.ink(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: fillsWidth ? CGFloat.infinity : nil)
                .frame(height: height ?? 34)
                .background(isOn ? Theme.green : Theme.ink(0.05),
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bars

/// Rounded progress track used for calories and for every macro row.
struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.5), value: progress)
    }
}

/// «Белки  54 / 120 г» + bar, turning amber once the goal is exceeded.
struct MacroRow: View {
    let name: String
    let value: Double
    let goal: Int
    let color: Color

    private var rounded: Int { Int(value.rounded()) }
    private var over: Int { max(0, rounded - goal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(name)
                    .golos(600, 12.5)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text(over > 0
                     ? "\(rounded) / \(goal) г · +\(over) сверх нормы"
                     : "\(rounded) / \(goal) г")
                    .golos(400, 12)
                    .tabularNumbers()
                    .foregroundStyle(over > 0 ? Theme.overText : Theme.ink(0.5))
            }
            ProgressBar(progress: goal > 0 ? value / Double(goal) : 0,
                        color: over > 0 ? Theme.fatBar : color)
        }
    }
}

// MARK: - Headers

/// ← + title, repeated at the top of every pushed screen.
struct NavBar: View {
    let title: String
    var titleSize: CGFloat = 19
    var titleWeight: Int = 700
    var titleColor: Color = Theme.ink
    var tint: Color = Theme.ink
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, -10)

            Text(title)
                .golos(titleWeight, titleSize)
                .foregroundStyle(titleColor)
            Spacer(minLength: 0)
        }
    }
}

/// Uppercase monospaced caption — «СВОЯ ЕДА», «БАЗА ПРОДУКТОВ», «НАЙДЕНО · 3».
struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .kerning(0.88)
            .foregroundStyle(Theme.ink(0.35))
    }
}

// MARK: - Tiles

/// One of the four coloured nutrition tiles on the product card.
struct MacroTile: View {
    let value: String
    let caption: String
    let valueColor: Color
    let captionColor: Color
    let background: Color
    var bordered: Bool = false
    var valueSize: CGFloat = 20

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .golos(700, valueSize)
                .tabularNumbers()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .golos(400, 11.5)
                .foregroundStyle(captionColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairlineStrong, lineWidth: bordered ? 1 : 0)
        )
    }
}

// MARK: - Steppers & fields

/// «Возраст  −  29 лет  +» row from onboarding and «Параметры и цель».
struct StepperRow: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .golos(500, 14.5)
                .foregroundStyle(Theme.ink(0.55))
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                StepperButton(symbol: "−", action: onDecrement)
                Text(value)
                    .golos(600, 15.5)
                    .tabularNumbers()
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 74)
                    .multilineTextAlignment(.center)
                StepperButton(symbol: "+", action: onIncrement)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StepperButton: View {
    let symbol: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 13
    var fontSize: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .golos(500, fontSize)
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
                .background(Color.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Поле для цифр.
///
/// Обёртка над UITextField, а не SwiftUI TextField, ради двух вещей:
/// — тап выделяет значение целиком, чтобы ввести новое, а не стирать старое посимвольно;
/// — поле сообщает о фокусе, и экран может убрать кнопку сохранения из-под пальца.
struct NumericField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var weight: Int = 700
    var size: CGFloat = 19
    var color: Color = Theme.ink
    var alignment: TextAlignment = .leading
    /// Разрешает десятичный разделитель — нужен форме своего блюда.
    var allowsDecimal: Bool = false
    /// Вызывается при получении и потере фокуса.
    var onFocusChange: ((Bool) -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = allowsDecimal ? .decimalPad : .numberPad
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.editingChanged(_:)),
                        for: .editingChanged)
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .vertical)

        // У цифровой клавиатуры нет «Return», поэтому даём явное «Готово».
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        bar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Готово", style: .done, target: context.coordinator,
                            action: #selector(Coordinator.dismissKeyboard))
        ]
        bar.sizeToFit()
        field.inputAccessoryView = bar
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.font = Golos.uiFont(weight, size)
        field.textColor = UIColor(color)
        field.textAlignment = context.coordinator.textAlignment
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.font: Golos.uiFont(weight, size),
                         .foregroundColor: UIColor(Theme.ink(0.3))]
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumericField

        init(parent: NumericField) { self.parent = parent }

        var textAlignment: NSTextAlignment {
            switch parent.alignment {
            case .trailing: return .right
            case .center: return .center
            default: return .left
            }
        }

        @objc func editingChanged(_ field: UITextField) {
            let cleaned = NumericField.sanitize(field.text ?? "", allowsDecimal: parent.allowsDecimal)
            if field.text != cleaned { field.text = cleaned }
            parent.text = cleaned
        }

        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.onFocusChange?(true)
            // Выделяем всё: следующий символ заменит значение целиком.
            DispatchQueue.main.async { field.selectAll(nil) }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            parent.onFocusChange?(false)
        }
    }

    static func sanitize(_ value: String, allowsDecimal: Bool) -> String {
        var seenSeparator = false
        var out = ""
        for ch in value {
            if ch.isNumber {
                out.append(ch)
            } else if allowsDecimal, ch == "," || ch == ".", !seenSeparator, !out.isEmpty {
                seenSeparator = true
                out.append(",")
            }
        }
        return String(out.prefix(6))
    }
}

extension String {
    /// Parses «12,5» and «12.5» alike.
    var ruDouble: Double? {
        Double(replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "\u{2009}", with: ""))
    }
}
