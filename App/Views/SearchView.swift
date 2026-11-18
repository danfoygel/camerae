import MapKit
import SwiftUI

struct SearchView: View {
    private enum Field { case from, to }

    @Environment(CatalogStore.self) private var catalog
    @State private var search = PlaceSearch()
    @State private var fromText = Endpoint.currentLocation.title
    @State private var toText = ""
    @State private var from: Endpoint? = .currentLocation
    @State private var to: Endpoint?
    @FocusState private var focus: Field?
    @State private var isPlanning = false
    @State private var errorMessage: String?
    @State private var planned: PlannedRoute?

    private static let sampleTrips = [
        ("San Francisco → Reno", "San Francisco, CA", "Reno, NV"),
        ("Los Angeles → Las Vegas", "Los Angeles, CA", "Las Vegas, NV"),
        ("San Diego → Sacramento", "San Diego, CA", "Sacramento, CA"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    endpointField("From", text: $fromText, field: .from)
                    endpointField("To", text: $toText, field: .to)
                }

                if focus != nil {
                    suggestions
                } else {
                    Section {
                        Button(action: planRoute) {
                            HStack {
                                Spacer()
                                if isPlanning { ProgressView() } else { Text("Find Cameras on Route").bold() }
                                Spacer()
                            }
                        }
                        .disabled(!canPlan)
                    } footer: {
                        if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    }

                    Section("Try a trip") {
                        ForEach(Self.sampleTrips, id: \.0) { trip in
                            Button(trip.0) { setTrip(from: trip.1, to: trip.2); planRoute() }
                        }
                    }

                    Section {
                        coverage
                    }
                }
            }
            .navigationTitle("Camerae")
            .navigationDestination(item: $planned) { RouteView(plan: $0) }
            .onChange(of: focus) { search.update(focus == .from ? fromText : focus == .to ? toText : "") }
            .task(id: catalog.matcher != nil) { runLaunchArgumentTrip() }
        }
    }

    private func endpointField(_ label: String, text: Binding<String>, field: Field) -> some View {
        LabeledContent(label) {
            TextField(field == .from ? "Start address or place" : "Destination", text: text)
                .focused($focus, equals: field)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(field == .from ? .next : .search)
                .foregroundStyle(field == .from && from == .currentLocation ? Color.accentColor : .primary)
                .onChange(of: text.wrappedValue) { _, newValue in
                    // Typing replaces a previously picked place.
                    if field == .from, from?.title != newValue { from = nil }
                    if field == .to, to?.title != newValue { to = nil }
                    search.update(newValue)
                }
                .onSubmit {
                    focus = field == .from ? .to : nil
                    if field == .to && canPlan { planRoute() }
                }
        }
    }

    @ViewBuilder private var suggestions: some View {
        Section {
            if focus == .from {
                Button { pick(.currentLocation) } label: {
                    Label("Current Location", systemImage: "location.fill")
                }
            }
            ForEach(search.results, id: \.self) { completion in
                Button { pick(.completion(completion)) } label: {
                    VStack(alignment: .leading) {
                        Text(completion.title).foregroundStyle(.primary)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var coverage: some View {
        switch catalog.state {
        case .loading:
            Label("Loading cameras…", systemImage: "hourglass")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
        case .ready(let catalog, _):
            let live = catalog.cameras.filter { $0.hlsURL != nil }.count
            VStack(alignment: .leading, spacing: 4) {
                Label("\(catalog.cameras.count.formatted()) cameras, \(live.formatted()) with live video",
                      systemImage: "video")
                Text("Coverage: California (Caltrans) and Nevada (NDOT).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var canPlan: Bool {
        catalog.matcher != nil && !isPlanning
            && !fromText.trimmingCharacters(in: .whitespaces).isEmpty
            && !toText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func pick(_ endpoint: Endpoint) {
        if focus == .from {
            from = endpoint
            fromText = endpoint.title
            focus = .to
        } else {
            to = endpoint
            toText = endpoint.title
            focus = nil
        }
    }

    private func setTrip(from start: String, to end: String) {
        from = .query(start); fromText = start
        to = .query(end); toText = end
    }

    private func planRoute() {
        guard let matcher = catalog.matcher, !isPlanning else { return }
        let start = from ?? .query(fromText)
        let end = to ?? .query(toText)
        focus = nil
        isPlanning = true
        errorMessage = nil
        Task {
            defer { isPlanning = false }
            do {
                planned = try await RoutePlanner.plan(from: start, to: end, matcher: matcher)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Development shortcut: `-from "San Francisco, CA" -to "Reno, NV"` plans a trip at launch.
    private func runLaunchArgumentTrip() {
        let defaults = UserDefaults.standard
        guard catalog.matcher != nil, planned == nil,
              let start = defaults.string(forKey: "from"), let end = defaults.string(forKey: "to")
        else { return }
        setTrip(from: start, to: end)
        planRoute()
    }
}

extension PlannedRoute: Hashable {
    static func == (lhs: PlannedRoute, rhs: PlannedRoute) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
