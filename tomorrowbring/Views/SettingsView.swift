//
//  SettingsView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.appLargeTitleSemibold)
                    .foregroundStyle(.brandGreen)

                substanceGoalsSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.appTitle3)
            }
        }
    }

    private var substanceGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Substance goals")
                .font(.appTitle3)
                .foregroundStyle(.secondary)

            ForEach(SubstanceKind.allCases) { kind in
                SubstanceGoalCard(kind: kind)
            }
        }
    }
}

// MARK: - Goal card

private struct SubstanceGoalCard: View {
    let kind: SubstanceKind
    @State private var goal: SubstanceGoal

    init(kind: SubstanceKind) {
        self.kind = kind
        _goal = State(initialValue: SubstanceGoal.load(for: kind))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .foregroundStyle(kind.tint)
                Text(kind.rawValue)
                    .font(.appBodySemibold)
            }

            Picker("Goal", selection: $goal.mode) {
                ForEach(SubstanceGoalMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

            if goal.mode == .targeted {
                Divider()
                HStack {
                    Text("Weekly limit")
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        "\(Int(goal.weeklyLimit ?? kind.defaultAmount)) \(kind.unit)",
                        value: Binding(
                            get: { goal.weeklyLimit ?? kind.defaultAmount },
                            set: { goal.weeklyLimit = $0 }
                        ),
                        in: kind.amountStep...500,
                        step: kind.amountStep
                    )
                    .font(.appSubheadline)
                }
            }

            Text(goal.mode.detail)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .onChange(of: goal) { _, newGoal in
            newGoal.save(for: kind)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
