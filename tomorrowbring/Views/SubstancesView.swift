//
//  SubstancesView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// Tracker for substances. A segmented control switches between the THC and
/// Alcohol trackers, each shown by `SubstanceTrackerView`.
struct SubstancesView: View {
    @State private var selectedKind: SubstanceKind = .thc

    var body: some View {
        VStack(spacing: 0) {
            Picker("Substance", selection: $selectedKind) {
                ForEach(SubstanceKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            SubstanceTrackerView(kind: selectedKind)
                // Rebuild the tracker (and its @Query) when the substance changes.
                .id(selectedKind)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Substances")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Substances")
                    .font(.appTitle3)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SubstancesView()
    }
    .modelContainer(SubstancePreviewData.container)
}
