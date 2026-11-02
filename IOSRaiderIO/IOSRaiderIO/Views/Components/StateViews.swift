import SwiftUI

struct LoadingStateView: View {
    let progress: LoadProgress

    var body: some View {
        VStack(spacing: 12) {
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
            } else {
                ProgressView()
            }
            Text(progress.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let error: APIError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: error.systemImage)
        } description: {
            Text(error.message)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Loading") {
    LoadingStateView(progress: LoadProgress(message: "Loading talents (3 of 10 players)…", completed: 3, total: 10))
}

#Preview("Rate limited") {
    ErrorStateView(error: .rateLimited) {}
}

#Preview("Offline") {
    ErrorStateView(error: .offline) {}
}
