import MapKit
import SwiftUI

struct SearchView: View {
    private enum Field { case from, to }

    @Environment(CatalogStore.self) private var catalog
    @State private var search = PlaceSearch()
    @State private var recents = RecentPlaces()
    @State private var home = HomeLocation()
    @State private var isEditingHome = false
    @State private var fromText = Endpoint.currentLocation.title
    @State private var toText = ""
    @State private var from: Endpoint? = .currentLocation
    @State private var to: Endpoint?
    @FocusState private var focus: Field?
    @State private var planning: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var planned: PlannedRoute?

    private static let sampleTrips = [
        ("San Francisco → Reno", "San Francisco, CA", "Reno, NV"),
        ("Los Angeles → Las Vegas", "Los Angeles, CA", "Las Vegas, NV"),
        ("San Diego → Sacramento", "San Diego, CA", "Sacramento, CA"),
    ]

    /// Shown on the search screen and under every route's camera list.
    static let drivingNotice = "For trip planning and passengers. Don't watch cameras while driving."

    var body: some View {
        List {
            Section {
                endpointField("From", text: $fromText, field: .from)
                endpointField("To", text: $toText, field: .to)
            }

            if focus != nil {
                suggestions
            } else {
                Section {
                    Button {
                        if isPlanning { cancelPlanning() } else { planRoute() }
                    } label: {
                        HStack {
                            Spacer()
                            if isPlanning {
                                ProgressView()
                                Text("Cancel")
                            } else {
                                Text("Find Cameras on Route").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isPlanning && !canPlan)
                } footer: {
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }

                homeSection

                Section("Try a trip") {
                    ForEach(Self.sampleTrips, id: \.0) { trip in
                        Button(trip.0) { setTrip(from: trip.1, to: trip.2); planRoute() }
                    }
                }

                Section {
                    coverage
                } footer: {
                    Text(Self.drivingNotice)
                }
            }
        }
        .navigationTitle("Plan a Route")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $planned) { RouteView(plan: $0) }
        .sheet(isPresented: $isEditingHome) { HomePicker(home: home, recents: recents) }
        .onChange(of: home.place) {
            refreshHome(&from, text: &fromText)
            refreshHome(&to, text: &toText)
        }
        .onChange(of: focus) { search.update(focus == .from ? fromText : focus == .to ? toText : "") }
        .task(id: catalog.matcher != nil) { runLaunchArgumentTrip() }
        // Opened to pick a destination; not when coming back from a route.
        .onAppear { if to == nil && toText.isEmpty { focus = .to } }
    }

    private func endpointField(_ label: String, text: Binding<String>, field: Field) -> some View {
        LabeledContent(label) {
            TextField(field == .from ? "Start address or place" : "Destination", text: text)
                .focused($focus, equals: field)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(field == .from ? .next : .search)
                .foregroundStyle((field == .from ? from : to)?.isShortcut == true ? Color.accentColor : .primary)
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
            if let place = homeSuggestion {
                Button { pick(.home(place)) } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Home").foregroundStyle(.primary)
                            Text(place.title).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "house.fill") }
                }
            }
            ForEach(recentSuggestions, id: \.self) { place in
                Button { pick(.recent(place)) } label: {
                    Label { Text(place.title).foregroundStyle(.primary) } icon: { Image(systemName: "clock") }
                }
                .swipeActions {
                    Button("Remove", role: .destructive) { recents.remove(place) }
                    Button("Set as Home") { home.set(place) }.tint(.indigo)
                }
            }
            ForEach(completionSuggestions, id: \.self) { completion in
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

    /// What's typed in the focused field, or nothing while it still shows a pick.
    private var typedText: String {
        let picked = focus == .from ? from : to
        return picked == nil ? (focus == .from ? fromText : toText).trimmingCharacters(in: .whitespaces) : ""
    }

    /// Previously used places; filtered by what's typed, or all of them while the field still shows a pick.
    private var recentSuggestions: [RecentPlace] {
        recents.matching(typedText)
    }

    /// Home, unless what's typed matches neither "Home" nor its address.
    private var homeSuggestion: RecentPlace? {
        guard let place = home.place else { return nil }
        let text = typedText
        guard text.isEmpty || "Home".localizedCaseInsensitiveContains(text)
                || place.title.localizedCaseInsensitiveContains(text) else { return nil }
        return place
    }

    @ViewBuilder private var homeSection: some View {
        Section("Home") {
            if let place = home.place {
                Button(action: planRouteHome) {
                    Label("Current Location to Home", systemImage: "house.fill")
                }
                .disabled(catalog.matcher == nil || isPlanning)
                Button { isEditingHome = true } label: {
                    HStack {
                        Text(place.title).foregroundStyle(Color.primary).lineLimit(2)
                        Spacer()
                        Text("Change")
                    }
                }
            } else {
                Button { isEditingHome = true } label: {
                    Label("Set Home Location", systemImage: "house")
                }
            }
        }
    }

    private var completionSuggestions: [MKLocalSearchCompletion] {
        let recentTitles = Set(recentSuggestions.map { $0.title.lowercased() })
        return search.results.filter { !recentTitles.contains(Endpoint.completion($0).title.lowercased()) }
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

    private var isPlanning: Bool { planning != nil }

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
        from = typed(start); fromText = start
        to = typed(end); toText = end
    }

    private func planRouteHome() {
        guard let place = home.place else { return }
        from = .currentLocation; fromText = Endpoint.currentLocation.title
        to = .home(place); toText = Endpoint.home(place).title
        planRoute()
    }

    /// Text that wasn't picked from the suggestions; "Home" means the saved Home when there is one.
    private func typed(_ text: String) -> Endpoint {
        if let place = home.place,
           text.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("Home") == .orderedSame {
            return .home(place)
        }
        return .query(text)
    }

    /// Keeps a field that shows Home pointing at the saved Home after it changes or is removed.
    private func refreshHome(_ endpoint: inout Endpoint?, text: inout String) {
        guard case .home = endpoint else { return }
        if let place = home.place {
            endpoint = .home(place)
        } else {
            endpoint = nil
            text = ""
        }
    }

    private func planRoute() {
        guard let matcher = catalog.matcher, !isPlanning else { return }
        let start = from ?? typed(fromText)
        let end = to ?? typed(toText)
        focus = nil
        errorMessage = nil
        planning = Task {
            // A cancelled plan may still finish later; by then a newer one may own `planning`.
            defer { if !Task.isCancelled { planning = nil } }
            do {
                let plan = try await RoutePlanner.plan(from: start, to: end, matcher: matcher)
                guard !Task.isCancelled else { return }
                plan.places.forEach(recents.add)
                planned = plan
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Gives up on the current plan right away, even if a MapKit call inside it never returns.
    private func cancelPlanning() {
        planning?.cancel()
        planning = nil
    }

    /// Development shortcut: `-from "San Francisco, CA" -to "Reno, NV"` plans a trip at launch
    /// ("Home" works too, once a Home is set).
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
