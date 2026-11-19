import MapKit
import SwiftUI

/// Searches for an address and saves it as Home.
struct HomePicker: View {
    let home: HomeLocation
    let recents: RecentPlaces

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearch()
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Home address", text: $text)
                        .focused($isFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onChange(of: text) { search.update(text) }
                        .onSubmit {
                            if !text.trimmingCharacters(in: .whitespaces).isEmpty { save(.query(text)) }
                        }
                } header: {
                    if let place = home.place { Text("Currently \(place.title)").textCase(nil) }
                } footer: {
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }

                Section {
                    ForEach(recents.matching(text), id: \.self) { place in
                        Button { save(.recent(place)) } label: {
                            Label { Text(place.title).foregroundStyle(.primary) } icon: { Image(systemName: "clock") }
                        }
                    }
                    ForEach(search.results, id: \.self) { completion in
                        Button { save(.completion(completion)) } label: {
                            VStack(alignment: .leading) {
                                Text(completion.title).foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if home.place != nil {
                    Section {
                        Button("Remove Home", role: .destructive) { home.set(nil); dismiss() }
                    }
                }
            }
            .navigationTitle("Set Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .disabled(isSaving)
            .overlay { if isSaving { ProgressView() } }
            .onAppear { isFocused = true }
        }
    }

    /// Resolves the picked place to a coordinate, saves it, and closes the sheet.
    private func save(_ endpoint: Endpoint) {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let c = try await endpoint.resolve().coordinate
                home.set(RecentPlace(title: endpoint.title, latitude: c.latitude, longitude: c.longitude))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
