import 'dart:math';

/// doubles each retry time (1 s, 2 s, 4 s...), capped at [max], with +/- [jitterFraction] random.
class BackoffPolicy {
  final Duration initial;
  final Duration max;
  final int maxAttempts;
  final double jitterFractions;

  const BackoffPolicy({
    this.initial = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.maxAttempts = 8,
    this.jitterFractions = 0.2,
  });
  Duration delayFor(int attempt, Random random) {
    final exponent = min(attempt - 1, 20);
    final baseMs = min(
      initial.inMilliseconds * (1 << exponent),
      max.inMilliseconds,
    );
    final jitterMs = (random.nextDouble() * 2 - 1) * jitterFractions * baseMs;
    return Duration(milliseconds: (baseMs + jitterMs).round());
  }
}
