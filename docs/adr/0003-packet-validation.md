# ADR-0003: Packet validation, integrity tracking and gap handling

- Status: Accepted
- Date: 2026-11-07
- Deciders: Siva

## Context
- BLE notifications are not acknowledged. The spike showed real loss in the instrument's
  send queue (about 15-22% at 2000 Hz with 14 samples per packet), plus the simulator can
  inject drops, corruption, pauses and disconnects.
- Measurement data may be signed off by a technician: a recording must never look more
  complete or more correct than it is.
- Each packet carries version, flags (bit0 = first after START), packetSeq, first-sample
  timestamp, sample rate, sample count N, N × 16 bytes of float32 samples, and a CRC-16/CCITT-FALSE.
- Reference test vectors exist (`protocol/test-vectors.json`, CRC check "123456789" -> 0x29B1).

## Options considered
1. Trust the transport, no app-level checks - simplest; corruption and loss stay silent.
2. Validate and silently drop bad packets - clean-looking data; loss is invisible.
3. Validate, reject bad packets, and detect and record every gap and error with the session.
4. Repair: interpolate missing samples - smooth charts; fabricates measurements.

Decoder location: inside a feature vs a pure-Dart `core/protocol` shared by `ble` and `recording`.

## Decision
We will validate every packet and record every loss (option 3), with a pure-Dart decoder
in `core/protocol`, written test-first against the reference vectors.

- Classification order: too_short (< 20 bytes) -> length_mismatch (!= 20 + 16N) ->
  bad_crc -> bad_version. Nothing inside a rejected packet is trusted, including its packetSeq.
- Multi-byte fields are read with `ByteData` and `Endian.little`. Samples start at byte 18,
  which is not 4-byte aligned, so they are copied into a `Float32List` (typed data, no
  per-sample objects) rather than viewed directly.
- An integrity tracker (pure Dart, stateful) records:
  - sequence gaps (from, to, count);
  - rejects by kind (too_short, length_mismatch, bad_crc, bad_version);
  - time gaps when a packet's timestamp exceeds the expected one by more than one packet window;
  - new segments when flags bit0 is set (after START or reconnect), never counted as gaps.
  A missing sequence number that belongs to a rejected packet counts as a reject, not a drop.
- Status errorCode 3 is recorded as an overflow event; errorCode 2 becomes an MtuTooSmall failure.
- A liveness watchdog raises an error when no packet arrives for a few seconds while streaming.
- An end-of-session check compares the end of the last packet window with the stop time (tail loss).
- All counters and gap records are stored with the session. Missing data is never filled in.

## Consequences
- Positive: every loss is visible and attributable to a cause; the decoder is testable
  without hardware; reference vectors catch CRC-variant and byte-order bugs early.
- Negative: tracker state must reset correctly on START and reconnect (a bug source, so it
  needs tests); the time-gap threshold is a judgement call (too small: false alarms with
  real-device jitter; too large: missed short pauses); the tail check is a heuristic because
  protocol v1 has no end-of-stream count; a rejected packet loses all its samples.
- Revisit if: protocol v2 adds an end-of-stream count or per-sample checksums; real instruments
  show timestamp jitter; partial salvage of damaged packets is required.

## Evidence
Spike: receiver-detected gaps matched the sender's drop count (1004 = 1004; 413 detected
+ 8 tail = 421). Timestamps stepped by exactly N × sample period in every run.