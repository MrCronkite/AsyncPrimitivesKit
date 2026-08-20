# AsyncPrimitivesKit

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

Custom policy with retry condition:

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

### AsyncDebouncer

Delays execution until a pause in calls — the last call within `interval` wins, all earlier ones are cancelled and never run.

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

Only the last call within the debounce window executes — useful for search-as-you-type, form validation, or any rapid-fire UI event you don't want to react to on every keystroke.

Backoff strategies:
- `.constant(_:)` — fixed delay between attempts
- `.linear(base:)` — delay grows linearly
- `.exponential(base:multiplier:jitter:)` — delay grows exponentially, with optional jitter to avoid thundering-herd retries

Respects `Task` cancellation — retries stop immediately if the enclosing task is cancelled.

