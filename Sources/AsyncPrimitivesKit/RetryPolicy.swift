//
//  RetryPolicy.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 19.08.2026.
//

import Foundation

/// Стратегия расчёта задержки между попытками.
public enum BackoffStrategy: Sendable {
    /// Всегда одна и та же пауза.
    case constant(TimeInterval)
    /// Пауза растёт линейно: base, 2×base, 3×base...
    case linear(base: TimeInterval)
    /// Пауза растёт экспоненциально: base × multiplier^(attempt-1),
    /// с опциональным случайным разбросом (jitter), чтобы избежать
    /// синхронных повторных запросов от множества клиентов сразу.
    case exponential(base: TimeInterval, multiplier: Double = 2.0, jitter: Bool = true)

    /// Считает задержку для конкретной попытки (нумерация с 1).
    func delay(forAttempt attempt: Int) -> TimeInterval {
        switch self {
        case .constant(let interval):
            return interval
        case .linear(let base):
            return base * Double(attempt)
        case .exponential(let base, let multiplier, let jitter):
            let raw = base * pow(multiplier, Double(attempt - 1))
            guard jitter else { return raw }
            // Разброс ±20% от расчётной задержки
            return raw * Double.random(in: 0.8...1.2)
        }
    }
}

/// Конфигурация правил повторного выполнения операции.
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let backoff: BackoffStrategy
    public let shouldRetry: @Sendable (Error) -> Bool

    public init(
        maxAttempts: Int,
        backoff: BackoffStrategy,
        shouldRetry: @escaping @Sendable (Error) -> Bool = { _ in true }
    ) {
        precondition(maxAttempts > 0, "maxAttempts должен быть больше 0")
        self.maxAttempts = maxAttempts
        self.backoff = backoff
        self.shouldRetry = shouldRetry
    }

    /// Готовые пресеты для быстрого старта.
    public static func exponential(
        maxAttempts: Int = 3,
        base: TimeInterval = 0.5
    ) -> RetryPolicy {
        RetryPolicy(maxAttempts: maxAttempts, backoff: .exponential(base: base))
    }

    public static func constant(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0
    ) -> RetryPolicy {
        RetryPolicy(maxAttempts: maxAttempts, backoff: .constant(delay))
    }
}
