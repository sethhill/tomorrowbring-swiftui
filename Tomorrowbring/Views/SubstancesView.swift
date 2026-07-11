//
//  SubstancesView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// Tracker for substances. A custom glass pill control switches between the THC
/// and Alcohol trackers, each shown by `SubstanceTrackerView`.
struct SubstancesView: View {
    @State private var selectedKind: SubstanceKind = .thc
    @Namespace private var pickerNamespace

    // React to substance goal changes so the picker stays in sync with settings.
    @AppStorage("substanceGoal-THC") private var thcGoalData = Data()
    @AppStorage("substanceGoal-Alcohol") private var alcoholGoalData = Data()

    private var trackedKinds: [SubstanceKind] {
        SubstanceKind.allCases.filter {
            $0 == .thc
                ? SubstanceGoal.isTracked(data: thcGoalData)
                : SubstanceGoal.isTracked(data: alcoholGoalData)
        }
    }

    /// The kind to actually display — falls back to the first tracked kind if
    /// the selected one has been disabled in settings.
    private var effectiveKind: SubstanceKind {
        trackedKinds.contains(selectedKind) ? selectedKind : (trackedKinds.first ?? selectedKind)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Substances")
                .font(.appLargeTitleSemibold)
                .foregroundStyle(.brandGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            if trackedKinds.count > 1 {
                substancePicker
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            SubstanceTrackerView(kind: effectiveKind)
                .id(effectiveKind)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var substancePicker: some View {
        HStack(spacing: 4) {
            ForEach(trackedKinds) { kind in
                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        selectedKind = kind
                    }
                } label: {
                    Text(kind.rawValue)
                        .font(.appBodySemibold)
                        .foregroundStyle(effectiveKind == kind ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if effectiveKind == kind {
                                Capsule()
                                    .fill(Color.brandOrange)
                                    .matchedGeometryEffect(id: "selectedPill", in: pickerNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SubstancesView()
    }
    .modelContainer(SubstancePreviewData.container)
}
#endif
