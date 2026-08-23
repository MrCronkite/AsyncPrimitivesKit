# AsyncPrimitivesKit

[![CI](https://github.com/MrCronkite/AsyncPrimitivesKit/actions/workflows/main.yml/badge.svg)](https://github.com/MrCronkite/AsyncPrimitivesKit/actions/workflows/main.yml)
[![Swift](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2015+-lightgrey.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Lightweight, tested concurrency primitives for Swift's native async/await — the utilities Combine gives you for free, now for structured concurrency.

## Why

Swift Concurrency ships `Task`, `TaskGroup`, `AsyncSequence` — but leaves out common patterns every app eventually reimplements: retry with backoff, debouncing, rate limiting. `AsyncPrimitivesKit` fills that gap with small, focused, well-tested building blocks.

## Requirements

- iOS 15+
- Swift 5.7+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MrCronkite/AsyncPrimitivesKit.git", from: "0.1.0")
]
```

Or in Xcode: `File → Add Package Dependencies...` and paste the repo URL.

## Primitives

### RetryPolicy

Retry an async operation with configurable backoff.

```swift
let result = try await withRetry(policy: .exponential(maxAttempts: 3)) {
    try await fetchData()
}
```

Custom policy with a retry condition — skip retrying errors that will never succeed:

```swift
let policy = RetryPolicy(
    maxAttempts: 5,
    backoff: .exponential(base: 0.5, multiplier: 2.0),
    shouldRetry: { error in
        // Don't retry client errors
        (error as? HTTPError)?.statusCode != 400
    }
)

let result = try await withRetry(policy: policy) {
    try await apiClient.fetch()
}
```

Backoff strategies:
- `.constant(_:)` — fixed delay between attempts
- `.linear(base:)` — delay grows linearly
- `.exponential(base:multiplier:jitter:)` — delay grows exponentially, with optional jitter to avoid thundering-herd retries

Respects `Task` cancellation — retries stop immediately if the enclosing task is cancelled.

### AsyncDebouncer

Delays execution until a pause in calls — the last call within `interval` wins, all earlier ones are cancelled and never run. Useful for search-as-you-type, form validation, or any rapid-fire UI event you don't want to react to on every keystroke.

```swift
let searchDebouncer = AsyncDebouncer<String>(interval: 0.3)

func onSearchTextChanged(_ text: String) {
    Task {
        await searchDebouncer.call(text) { query in
            let results = try? await searchAPI.search(query)
            await MainActor.run { self.results = results ?? [] }
        }
    }
}
```

### AsyncSemaphore

Limits how many operations run concurrently — the rest wait their turn without blocking a thread.

```swift
let semaphore = AsyncSemaphore(limit: 4)

try await withThrowingTaskGroup(of: Void.self) { group in
    for url in imageURLs {
        group.addTask {
            try await semaphore.withPermit {
                try await downloadImage(url)
            }
        }
    }
    try await group.waitForAll()
}
```

`withPermit` automatically releases the slot even if the operation throws — use it instead of manual `acquire`/`release` to avoid leaking permits.

### AsyncRateLimiter

Limits operations to a maximum rate over time (token bucket algorithm) — distinct from `AsyncSemaphore`, which limits concurrency, not throughput over time. Use this when calling an API with a hard rate limit (e.g. "10 requests/second").

```swift
let limiter = AsyncRateLimiter(capacity: 5, refillRate: 5) // burst up to 5, then 5/sec sustained

for id in itemIDs {
    try await limiter.withPermit {
        try await apiClient.fetch(id)
    }
}
```

`capacity` allows short bursts; `refillRate` (tokens/sec) caps the sustained rate.

## Testing

```bash
swift test
```

## Contributing

Issues and PRs are welcome. Please make sure `swift test` passes before submitting.

## License

MIT — see [LICENSE](LICENSE) for details.

