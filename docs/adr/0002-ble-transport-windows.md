# ADR-0002: BLE transport on Windows (universal_ble), verified by spike

- Status: Accepted
- Date: 2026-11-07
- Deciders: Siva

## Context
- Windows desktop is the primary target; the app is the BLE central for the instrument.
- Flutter BLE support on Windows is less proven than on mobile, and on Windows the
  operating system negotiates the MTU; the app cannot request it.
- Our protocol needs MTU >= 39 to stream at all (one sample per packet) and MTU >= 503
  for the maximum of 30 samples per packet. At MTU 23 START is accepted but nothing streams.
- Recording must be lossless, and any loss must be detected and recorded.
- Fallback if Windows failed: an Android phone (Phone B) as the central.
- We ran a time-boxed, throwaway spike against the PowerSim simulator on Phone A
  before writing any architecture code that depends on BLE.

## Options considered
1. universal_ble on Windows - documented Windows backend (scan, connect, discovery, read,
   write, notify), one API across platforms, BSD-3 licence; MTU is query-only on Windows.
2. flutter_blue_plus with its Windows implementation - mature on mobile; its endorsed
   Windows backend was an early 0.0.x release when checked; licence terms not verified.
3. Android phone as the central - the app can request MTU 517 and a high-priority
   connection; but Windows would no longer be the BLE platform.
4. Protocol-level fragmentation - works at any MTU; requires protocol and simulator
   changes plus reassembly with its own failure modes.

## Decision
We will use universal_ble on Windows as the BLE central (option 1).

At 2000 Hz the instrument must use 30 samples per packet (the largest N the MTU allows);
the app always uses the largest N the negotiated MTU permits and warns when packets
arrive with a smaller N than expected.

Integration rules adopted from the spike:
- Identify the instrument by service UUID when scanning and by the Info `device` field
  once connected - never by address (it changed on every connection).
- Confirm START and STOP through Status notifications (state 1 / state 0), never by the
  write acknowledgement alone. A write timeout means "outcome unknown".
- No characteristic reads while a high-rate stream is running.
- A liveness watchdog: no packet within a few seconds of START or during recording is an error.
- Record sequence gaps, CRC errors, time gaps and overflow (error code 3) with the session;
  add an end-of-session check for tail loss.
- Always run STOP/cleanup on failure paths; use full restarts (not hot restart) when testing BLE.

## Consequences
- Positive: Windows stays the primary BLE platform; no protocol change; one BLE code path
  for Windows and Android behind our own interface (package API differences stay in one file).
- Negative / risks:
  - Throughput margin: on this laptop + phone the link delivered at most ~119
    notifications/s; 2000 Hz at N=30 needs ~67/s (~56% of the observed ceiling).
    Not characterised on other adapters or instruments.
  - A peripheral configured with a small N at 2000 Hz (e.g. N=14, ~143 packets/s) loses
    ~15-22% of packets on this central (detected, but lost).
  - The app cannot tune connection parameters on Windows.
  - Not verified: long-read path (Info fits in one read at MTU 517), 30-minute sessions,
    Android as central, iOS, 500 Hz and release builds (inferred safe, not measured).
- Revisit if: loss appears in the 30-minute soak (Phase 2); a different adapter or
  instrument negotiates a smaller MTU; universal_ble changes major version; the
  notification ceiling must be raised (then consider an Android central or USB/Wi-Fi).

## Evidence
Environment: Windows laptop, Intel Bluetooth adapter, universal_ble 3.2.0,
PowerSim simulator (firmware 1.0.0) on Android Phone A. No pairing prompt on any run.

| Run | Rate | N | Duration | Received | Missing | Sender sent / dropped | Result |
|---|---|---|---|---|---|---|---|
| 1-2 | 100 Hz | 14 | 20 s | 143 | 0 | 143 / 0 | Lossless, two-end match |
| 4 | 2000 Hz | 14 | ~32 s (crashed) | - | 1004 | 3585 / 1004 | ~22% loss, all detected |
| 5 | 2000 Hz | 14 | 20 s | 2386 | 413 | 2386 / 421 | ~15% loss; 8 packets tail loss |
| A | 2000 Hz | 30 | 20 s | 1336 | 0 | 1336 / 0 | Lossless, two-end match |
| Soak | 2000 Hz | 30 | 180 s | 12006 | 0 | 12006 / 0 | Lossless, two-end match |

Other findings:
- MTU 517 negotiated, confirmed independently by the package and the peripheral.
- Info: 172 bytes received complete and parsed.
- Device address differed on every connection (random/rotating addresses).
- SET_RATE then START works on a fresh launch; an earlier failure of the same sequence
  coincided with a hot restart (most likely cause; one run of evidence).
- At 2000 Hz / N=14 the STOP write acknowledgement timed out although the device stopped
  (confirmed by Status); at N=30 it returned immediately.