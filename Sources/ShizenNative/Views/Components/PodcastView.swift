import SwiftUI

struct PodcastView: View {
    @StateObject private var podcastManager = PodcastManager()
    @State private var searchText = ""
    @State private var selectedPodcast: ItunesPodcastResponse?
    @State private var isDownloading = false
    @State private var selectedTab = "Search"
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var recentSearches: [String] = []
    let onEpisodeDownloaded: (URL) -> Void
    
    private let tabs = ["Search", "Recent"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                ForEach(tabs, id: \.self) { tab in
                    Text(tab).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == "Search" {
                // Search bar
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search Japanese podcasts...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding()
                    
                    // Recent searches
                    if searchText.isEmpty && !recentSearches.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                Text("Recent Searches")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(recentSearches, id: \.self) { search in
                                    Button(action: {
                                        searchText = search
                                        performSearch()
                                    }) {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                            Text(search)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            
            if let selectedPodcast = selectedPodcast {
                // Episodes view
                VStack {
                    HStack {
                        Button(action: { self.selectedPodcast = nil }) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        Spacer()
                    }
                    .padding()
                    
                    if let feedUrl = selectedPodcast.feedUrl {
                        PodcastEpisodesView(
                            podcast: selectedPodcast,
                            feedUrl: feedUrl,
                            podcastManager: podcastManager,
                            onEpisodeDownloaded: onEpisodeDownloaded,
                            onError: { error in
                                errorMessage = error
                                showError = true
                            }
                        )
                    } else {
                        Text("No episodes available")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Podcasts grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        if selectedTab == "Search" {
                            if podcastManager.isSearching {
                                ProgressView("Searching...")
                            } else if searchText.isEmpty {
                                EmptyView()
                            } else {
                                ForEach(podcastManager.searchResults, id: \.trackId) { podcast in
                                    PodcastCard(podcast: podcast) {
                                        selectedPodcast = podcast
                                    }
                                }
                            }
                        } else {  // Recent tab
                            ForEach(podcastManager.recentPodcasts, id: \.trackId) { podcast in
                                PodcastCard(podcast: podcast) {
                                    selectedPodcast = podcast
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onAppear {
            loadRecentSearches()
            Task {
                await podcastManager.loadRecentPodcasts()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        // Add to recent searches
        if !recentSearches.contains(searchText) {
            recentSearches.insert(searchText, at: 0)
            if recentSearches.count > 10 {  // Keep only last 10 searches
                recentSearches.removeLast()
            }
            saveRecentSearches()
        }
        
        Task {
            await podcastManager.searchPodcasts(searchText)
        }
    }
    
    private func loadRecentSearches() {
        if let searches = UserDefaults.standard.stringArray(forKey: "recentPodcastSearches") {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recentPodcastSearches")
    }
}

struct PodcastEpisodesView: View {
    let podcast: ItunesPodcastResponse
    let feedUrl: String
    @ObservedObject var podcastManager: PodcastManager
    let onEpisodeDownloaded: (URL) -> Void
    let onError: (String) -> Void
    
    @State private var episodes: [PodcastEpisode] = []
    @State private var isLoading = false
    @State private var currentlyDownloading: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading episodes...")
            } else {
                List(episodes) { episode in
                    PodcastEpisodeRow(
                        episode: episode,
                        isDownloading: currentlyDownloading == episode.id
                    ) {
                        downloadEpisode(episode)
                    }
                }
            }
        }
        .onAppear {
            loadEpisodes()
        }
    }
    
    private func loadEpisodes() {
        isLoading = true
        Task {
            do {
                episodes = try await podcastManager.loadEpisodes(from: feedUrl)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    private func downloadEpisode(_ episode: PodcastEpisode) {
        Task {
            currentlyDownloading = episode.id
            defer { currentlyDownloading = nil }
            
            do {
                let url = try await podcastManager.downloadEpisode(episode)
                await MainActor.run {
                    onEpisodeDownloaded(url)
                }
            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
    }
}

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    let isDownloading: Bool
    let onDownload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(episode.title)
                .font(.headline)
            
            Text(episode.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(formatDuration(episode.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}
