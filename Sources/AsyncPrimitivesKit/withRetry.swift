//
//  withRetry.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 19.08.2026.
//

import Foundation

/// Ошибка, брошенная когда все попытки исчерпаны.
public struct RetryExhaustedError: Error {
    public let attempts: Int
    public let lastError: Error
}

/// Выполняет асинхронную операцию с повторными попытками согласно policy.
///
/// - Parameters:
///   - policy: правила повторов (число попыток, backoff, условие ретрая)
///   - operation: асинхронная операция, которую нужно выполнить
/// - Returns: результат успешного выполнения
/// - Throws: `RetryExhaustedError`, если все попытки исчерпаны,
///           или `CancellationError`, если Task была отменена,
///           или исходную ошибку, если `shouldRetry` вернул false
public func withRetry<T>(
    policy: RetryPolicy,
    sleeper: Sleeper = RealSleeper(),
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error!

    for attempt in 1...policy.maxAttempts {
        // Проверяем отмену перед КАЖДОЙ попыткой — если снаружи
        // отменили Task, немедленно прекращаем и не тратим лишнюю попытку.
        try Task.checkCancellation()

        do {
            return try await operation()
        } catch {
            lastError = error

            // Если ошибка не подлежит ретраю (например, 400 Bad Request) —
            // выбрасываем её сразу, не тратя оставшиеся попытки.
            guard policy.shouldRetry(error) else {
                throw error
            }

            // Если это была последняя попытка — выходим из цикла,
            // ниже бросим RetryExhaustedError.
            guard attempt < policy.maxAttempts else {
                break
            }

            let delay = policy.backoff.delay(forAttempt: attempt)
            try await sleeper.sleep(for: delay)
        }
    }

    throw RetryExhaustedError(attempts: policy.maxAttempts, lastError: lastError)
}
