import SwiftUI
@preconcurrency import WebKit

struct YouTubeView: View {
    @StateObject private var youtubeManager = YoutubeManager()
    @State private var urlString = ""
    @State private var selectedVideo: YouTubeVideo?
    @State private var showWebView = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isDownloading = false
    var onVideoDownloaded: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // URL input
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("Paste YouTube URL", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        if !urlString.isEmpty {
                            downloadVideo(urlString)
                        }
                    }) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            
            // Placeholder for content
            Text("Enter a YouTube URL to download")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showWebView) {
            YouTubeBrowserSheet(youtubeManager: youtubeManager, onVideoSelected: { url in
                urlString = url
                showWebView = false
                downloadVideo(url)
            })
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showWebView = true }) {
                    Image(systemName: "safari")
                }
            }
        }
    }
    
    private func downloadVideo(_ url: String) {
        isDownloading = true
        
        Task {
            do {
                let audioUrl = try await youtubeManager.downloadAudio(from: url)
                await MainActor.run {
                    onVideoDownloaded(audioUrl)
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isDownloading = false
                }
            }
        }
    }
}


struct YouTubeVideoCard: View {
    let video: YouTubeVideo
    let onDownload: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fill)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(video.channelTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(video.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onDownload) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Download")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct YouTubeBrowserSheet: View {
    @ObservedObject var youtubeManager: YoutubeManager
    let onVideoSelected: (String) -> Void
    @State private var webView: WKWebView
    @Environment(\.dismiss) private var dismiss
    @State private var currentURL: String = ""
    @State private var showDownloadConfirmation = false
    @State private var browserDelegate: YouTubeBrowserDelegate?
    @State private var isLoading = false
    @State private var isDownloading = false
    
    init(youtubeManager: YoutubeManager, onVideoSelected: @escaping (String) -> Void) {
        self._youtubeManager = ObservedObject(wrappedValue: youtubeManager)
        self.onVideoSelected = onVideoSelected
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        self._webView = State(initialValue: WKWebView(frame: .zero, configuration: config))
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    stopVideo()
                    if !isDownloading {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .disabled(isDownloading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                Spacer()
                
                if isValidYouTubeURL(currentURL) {
                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Download") {
                            showDownloadConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            
            YouTubeBrowserWebView(webView: webView) { url in
                currentURL = url
            }
        }
        .frame(width: 800, height: 600)
        .alert("Download Video", isPresented: $showDownloadConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Download") {
                handleDownload()
            }
        } message: {
            Text("Do you want to download the audio from this video?")
        }
        .onAppear {
            setupWebView()
        }
        .onDisappear {
            stopVideo()
        }
        .interactiveDismissDisabled(isDownloading)
    }
    
    private func setupWebView() {
        browserDelegate = YouTubeBrowserDelegate(
            onURLChange: { url in
                currentURL = url
            },
            onLoadingStateChange: { loading in
                isLoading = loading
            },
            onError: { error in
                // Handle error
            }
        )
        webView.navigationDelegate = browserDelegate
        webView.load(URLRequest(url: URL(string: "https://youtube.com")!))
    }
    
    private func handleDownload() {
        guard isValidYouTubeURL(currentURL) else { return }
        
        isDownloading = true
        stopVideo()
        
        webView.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause());") { result, error in
            if error == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onVideoSelected(currentURL)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isDownloading = false
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func stopVideo() {
        let javascript = """
            document.querySelectorAll('video').forEach(v => {
                v.pause();
                v.remove();
            });
            document.querySelectorAll('iframe').forEach(f => f.remove());
        """
        webView.evaluateJavaScript(javascript) { _, _ in }
    }
    
    private func isValidYouTubeURL(_ url: String) -> Bool {
        let isValid = url.contains("youtube.com/watch?v=") || url.contains("youtu.be/")
        print("URL validation for \(url): \(isValid)")
        return isValid
    }
}

struct YouTubeBrowserWebView: NSViewRepresentable {
    let webView: WKWebView
    let onURLChange: (String) -> Void
    
    func makeNSView(context: Context) -> WKWebView {
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        
        let css = """
        video { display: none !important; }
        iframe { display: none !important; }
        """
        let script = WKUserScript(source: css, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onURLChange: onURLChange)
    }
    
    class Coordinator: NSObject {
        let onURLChange: (String) -> Void
        
        init(onURLChange: @escaping (String) -> Void) {
            self.onURLChange = onURLChange
            super.init()
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == #keyPath(WKWebView.url) {
                if let url = (object as? WKWebView)?.url?.absoluteString {
                    onURLChange(url)
                }
            }
        }
    }
}

class YouTubeBrowserDelegate: NSObject, WKNavigationDelegate {
    let onURLChange: (String) -> Void
    let onLoadingStateChange: (Bool) -> Void
    let onError: (String) -> Void
    
    init(onURLChange: @escaping (String) -> Void, 
         onLoadingStateChange: @escaping (Bool) -> Void,
         onError: @escaping (String) -> Void) {
        self.onURLChange = onURLChange
        self.onLoadingStateChange = onLoadingStateChange
        self.onError = onError
        super.init()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingStateChange(true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingStateChange(false)
        if let url = webView.url?.absoluteString {
            onURLChange(url)
        }
        
        let javascript = """
        document.querySelectorAll('video').forEach(v => {
            v.pause();
            v.autoplay = false;
            v.removeAttribute('autoplay');
        });
        """
        webView.evaluateJavaScript(javascript) { _, _ in }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString {
            if navigationAction.navigationType == .other,
               (url.contains("googlevideo.com") || url.contains("youtube.com/videoplayback")) {
                decisionHandler(.cancel)
                return
            }
            
            onURLChange(url)
        }
        decisionHandler(.allow)
    }
}
