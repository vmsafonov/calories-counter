import SwiftUI

/// Three steps: goal → body parameters → the norm they produce (Mifflin–St Jeor).
struct OnboardingScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    var body: some View {
        let calculated = Goals.calculated(body: store.bodyProfile, goal: store.goal)

        VStack(spacing: 0) {
            HStack(spacing: 6) {
                progressSegment(filled: true)
                progressSegment(filled: nav.onboardingStep >= 2)
                progressSegment(filled: nav.onboardingStep >= 3)
            }
            .padding(.top, 8)
            .padding(.bottom, 26)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch nav.onboardingStep {
                    case 1: goalStep
                    case 2: bodyStep
                    default: normStep(calculated)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            PrimaryButton(title: nav.onboardingStep == 3 ? "Начать вести дневник" : "Далее") {
                if nav.onboardingStep < 3 {
                    nav.onboardingStep += 1
                } else {
                    store.finishOnboarding(goals: calculated)
                    nav.onboardingStep = 1
                    nav.go(.diary)
                }
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 34)
    }

    private func progressSegment(filled: Bool) -> some View {
        Capsule()
            .fill(filled ? Theme.green : Theme.ink(0.1))
            .frame(height: 4)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Какая у вас цель?")
                .golos(700, 27)
                .kerning(-0.54)
                .foregroundStyle(Theme.ink)
            Text("От этого зависит дефицит калорий и распределение белков, жиров и углеводов.")
                .golos(400, 14, lineHeight: 1.5)
                .foregroundStyle(Theme.ink(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.bottom, 26)

            VStack(spacing: 10) {
                ForEach(GoalKind.allCases, id: \.self) { goal in
                    let isOn = store.goal == goal
                    Button {
                        store.setGoal(goal)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title)
                                    .golos(600, 15.5)
                                    .foregroundStyle(Theme.ink)
                                Text(goal.subtitle)
                                    .golos(400, 12.5)
                                    .foregroundStyle(Theme.ink(0.45))
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Circle()
                                .fill(isOn ? Theme.green : Color.clear)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().stroke(isOn ? Theme.green : Theme.ink(0.18), lineWidth: 1.5)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(isOn ? Theme.greenTint : Color.white,
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isOn ? Theme.green : Theme.ink(0.1), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Немного о вас")
                .golos(700, 27)
                .kerning(-0.54)
                .foregroundStyle(Theme.ink)
            Text("Нужно для расчёта нормы. Меняется в любой момент.")
                .golos(400, 14, lineHeight: 1.5)
                .foregroundStyle(Theme.ink(0.5))
                .padding(.top, 10)
                .padding(.bottom, 24)

            BodyParametersEditor()

            Text("Расчёт по формуле Миффлина — Сан Жеора с поправкой на активность.")
                .golos(400, 12.5, lineHeight: 1.5)
                .foregroundStyle(Theme.greenDark)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.greenTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 18)
        }
    }

    // MARK: - Step 3

    private func normStep(_ goals: Goals) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ваша норма на день")
                .golos(700, 27)
                .kerning(-0.54)
                .foregroundStyle(Theme.ink)
            Text(store.goal.calcNote)
                .golos(400, 14, lineHeight: 1.5)
                .foregroundStyle(Theme.ink(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Ru.grouped(goals.kcal))
                        .golos(800, 44)
                        .kerning(-1.32)
                        .tabularNumbers()
                        .foregroundStyle(Theme.ink)
                    Text("ккал")
                        .golos(500, 15)
                        .foregroundStyle(Theme.ink(0.45))
                }
                .padding(.bottom, 20)

                HStack(spacing: 8) {
                    normTile(value: "\(goals.protein) г", caption: "белки",
                             valueColor: Theme.proteinText, background: Theme.proteinTint)
                    normTile(value: "\(goals.fat) г", caption: "жиры",
                             valueColor: Theme.fatText, background: Theme.fatTint)
                    normTile(value: "\(goals.carbs) г", caption: "углев.",
                             valueColor: Theme.carbText, background: Theme.carbTint)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            Button {
                nav.onboardingStep = 2
            } label: {
                Text("← Изменить параметры")
                    .golos(500, 13.5)
                    .foregroundStyle(Theme.ink(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }

    private func normTile(value: String, caption: String,
                          valueColor: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .golos(700, 19)
                .tabularNumbers()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .golos(400, 11.5)
                .foregroundStyle(valueColor.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
