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

    var body: some View {
        VStack(spacing: 0) {
            Text("Substances")
                .font(.appLargeTitleSemibold)
                .foregroundStyle(.brandGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            substancePicker
                .padding(.horizontal)
                .padding(.vertical, 8)

            SubstanceTrackerView(kind: selectedKind)
                // Rebuild the tracker (and its @Query) when the substance changes.
                .id(selectedKind)
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
            ForEach(SubstanceKind.allCases) { kind in
                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        selectedKind = kind
                    }
                } label: {
                    Text(kind.rawValue)
                        .font(.appBodySemibold)
                        .foregroundStyle(selectedKind == kind ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if selectedKind == kind {
                                Capsule()
                                    .fill(.white)
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

#Preview {
    NavigationStack {
        SubstancesView()
    }
    .modelContainer(SubstancePreviewData.container)
}
