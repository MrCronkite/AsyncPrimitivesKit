//
//  AsyncRateLimiter.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 23.08.2026.
//

import Foundation

/// Ограничивает скорость выполнения операций по алгоритму Token Bucket.
///
/// Допускает кратковременные всплески до `capacity` операций подряд,
/// но в среднем не превышает `refillRate` операций в секунду.
public actor AsyncRateLimiter {
    private let capacity: Double
    private let refillRate: Double // токенов в секунду
    private let sleeper: Sleeper

    private var availableTokens: Double
    private var lastRefillTime: ContinuousClockTime

    /// - Parameters:
    ///   - capacity: максимальное число токенов в "ведре" — допустимый
    ///               размер всплеска (сколько операций можно сделать подряд
    ///               без ожидания, если ведро полное).
    ///   - refillRate: скорость пополнения токенов, операций в секунду.
    public init(capacity: Int, refillRate: Double, sleeper: Sleeper = RealSleeper()) {
        precondition(capacity > 0, "capacity должен быть больше 0")
        precondition(refillRate > 0, "refillRate должен быть больше 0")
        self.capacity = Double(capacity)
        self.refillRate = refillRate
        self.sleeper = sleeper
        self.availableTokens = Double(capacity)
        self.lastRefillTime = .now()
    }

    /// Ждёт, пока не станет доступен токен, затем "тратит" его.
    public func acquire() async throws {
        refillIfNeeded()

        if availableTokens >= 1.0 {
            availableTokens -= 1.0
            return
        }

        // Токенов нет — считаем, сколько нужно ждать до появления одного.
        let tokensNeeded = 1.0 - availableTokens
        let waitTime = tokensNeeded / refillRate

        try await sleeper.sleep(for: waitTime)

        refillIfNeeded()
        availableTokens = max(0, availableTokens - 1.0)
    }

    /// Выполняет `operation`, предварительно дождавшись доступного токена.
    public func withPermit<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await acquire()
        return try await operation()
    }

    /// Пополняет токены пропорционально прошедшему времени с последнего пополнения.
    private func refillIfNeeded() {
        let now = ContinuousClockTime.now()
        let elapsed = now.secondsSince(lastRefillTime)
        guard elapsed > 0 else { return }

        let newTokens = elapsed * refillRate
        availableTokens = min(capacity, availableTokens + newTokens)
        lastRefillTime = now
    }
}

/// Минимальная обёртка над монотонным временем — не зависит от системных
/// часов (в отличие от `Date()`, который может "прыгать" при синхронизации
/// времени устройства), что критично для корректных расчётов интервалов.
struct ContinuousClockTime {
    private let value: UInt64

    static func now() -> ContinuousClockTime {
        ContinuousClockTime(value: DispatchTime.now().uptimeNanoseconds)
    }

    func secondsSince(_ other: ContinuousClockTime) -> Double {
        Double(value - other.value) / 1_000_000_000
    }
}
