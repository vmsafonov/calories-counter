import SwiftUI

/// «Параметры и цель» — goal, sex, age / height / weight, activity, and the norm they imply.
struct BodyGoalScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    var body: some View {
        let profile = store.bodyProfile
        let calculated = Goals.calculated(body: profile, goal: store.goal)

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavBar(title: "Параметры и цель") { nav.go(.profile) }
                        .padding(.bottom, 16)

                    Text("Цель")
                        .golos(500, 12)
                        .foregroundStyle(Theme.ink(0.5))
                        .padding(.bottom, 10)

                    HStack(spacing: 6) {
                        ForEach(GoalKind.allCases, id: \.self) { goal in
                            Chip(title: goal.chipTitle, isOn: store.goal == goal,
                                 height: 44, horizontalPadding: 8, cornerRadius: 13,
                                 fillsWidth: true) {
                                store.setGoal(goal)
                            }
                        }
                    }
                    .padding(.bottom, 18)

                    BodyParametersEditor()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Норма по этим данным")
                            .golos(400, 12.5, lineHeight: 1.5)
                            .foregroundStyle(Theme.greenDark)
                        Text(calculated.summaryLine)
                            .golos(600, 14.5, lineHeight: 1.3)
                            .tabularNumbers()
                            .foregroundStyle(Theme.greenDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Theme.greenTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }

            HStack(spacing: 8) {
                SecondaryButton(title: "Готово") { nav.go(.profile) }
                PrimaryButton(title: "Применить норму", fontSize: 15) {
                    store.setGoals(calculated)
                    nav.go(.profile)
                    nav.flash("Норма пересчитана")
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
            .background(
                Color.white
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

/// Sex + age / height / weight steppers + activity. Shared by onboarding and the profile.
struct BodyParametersEditor: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let profile = store.bodyProfile

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Пол")
                    .golos(500, 14.5)
                    .foregroundStyle(Theme.ink(0.55))
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach(Sex.allCases, id: \.self) { sex in
                        Chip(title: sex.title, isOn: profile.sex == sex,
                             height: 40, cornerRadius: 12, fontSize: 13) {
                            var updated = store.bodyProfile
                            updated.sex = sex
                            store.setBody(updated)
                        }
                    }
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            StepperRow(label: "Возраст", value: "\(profile.age) \(Ru.years(profile.age))") {
                update { $0.age = max(14, $0.age - 1) }
            } onIncrement: {
                update { $0.age = min(99, $0.age + 1) }
            }

            StepperRow(label: "Рост", value: "\(profile.height) см") {
                update { $0.height = max(130, $0.height - 1) }
            } onIncrement: {
                update { $0.height = min(220, $0.height + 1) }
            }

            StepperRow(label: "Вес сейчас", value: "\(profile.weight) кг") {
                update { $0.weight = max(35, $0.weight - 1) }
            } onIncrement: {
                update { $0.weight = min(250, $0.weight + 1) }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Активность")
                    .golos(500, 14.5)
                    .foregroundStyle(Theme.ink(0.55))
                HStack(spacing: 6) {
                    ForEach(Activity.allCases, id: \.self) { activity in
                        Chip(title: activity.title, isOn: profile.activity == activity,
                             height: 42, horizontalPadding: 8, cornerRadius: 12,
                             fontSize: 13, fillsWidth: true) {
                            update { $0.activity = activity }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func update(_ change: (inout BodyProfile) -> Void) {
        var updated = store.bodyProfile
        change(&updated)
        store.setBody(updated)
    }
}
