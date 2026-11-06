# ADR-0001: Application architecture and code structure

- Status: Accepted
- Date: 2026-11-06
- Deciders: Siva

## Context
- PowerStream is a Flutter companion app for a power-measurement instrument.
  Windows is the primary target; Android must work and iOS must stay possible.
- Transport is BLE today; Wi-Fi or USB instruments are plausible later.
- Data arrives at up to 2000 samples/s × 4 channels. Recording must be lossless,
  and any upstream loss must be detected and recorded.
- Offline-first: the local database is the source of truth; cloud sync copies from it.
- Independent capabilities: connection, recording, sessions/history, sync, file import/upload.
- Small team (<10): code must have clear ownership, be reviewable, and be testable
  without hardware.
- Likely to change independently: the BLE package (Windows maturity unverified),
  the storage engine, the cloud API.

## Options considered
Structure:
1. Layer-first (data/domain/presentation at top level) — simple for small apps; a feature
   change spans three trees, no ownership, easy hidden coupling.
2. Feature-first with Clean layers inside each feature — cohesion and ownership; risk of
   `core/` becoming a dumping ground and of cross-feature tangles.
3. One Dart package per feature (monorepo) — compiler-enforced boundaries; tooling and
   versioning overhead not justified for one app.

Architecture style:
4. MVVM per Flutter's architecture guide (domain layer optional) — lighter; boundaries
   blur as logic grows.
5. Clean Architecture (pure-Dart domain, data, presentation) — swappable details and
   hardware-free tests; costs mappers and indirection.

Dependency injection:
6. Manual constructor wiring only — compile-time safe; verbose; lifetimes managed by hand.
7. get_it as a container + constructor injection — lazy creation, dispose hooks, one wiring
   place; missing registrations fail at runtime.
8. Riverpod — compile-safe, no BuildContext; a second reactive paradigm alongside Bloc.
9. Provider/BlocProvider only — natural UI scoping; unusable outside the widget tree.

## Decision
We will use feature-first Clean Architecture (option 2 + 5) with features `ble`,
`recording`, `sessions`, `sync`, `import`, `diagnostics`, each split into
domain/data/presentation, and a `core/` for genuinely shared, stable code (protocol
decoder, the single drift database, network client, backoff).

Rules:
- Within a feature: presentation → domain ← data. Domain is pure Dart (no Flutter,
  drift, dio or BLE imports).
- Across features: import only another feature's domain; the feature graph is acyclic.
  `core/` imports no feature.
- Blocs depend only on use cases (thin pass-through use cases accepted for consistency).
- All classes receive dependencies via constructors. get_it (option 7) is used only in
  the composition root (`app/di`) and at the widget boundary; BlocProvider owns screen Blocs.
- High-rate data crosses layer boundaries in batches, never per sample.

## Consequences
- Positive: BLE package, storage engine and API can be swapped behind domain interfaces;
  parser and Blocs are testable without hardware; clear feature ownership.
- Negative: more files and mappers (one measurement exists in wire, DB, domain and API
  shapes); some thin use cases; `core/` knows every table definition (a single database
  is required for cross-feature transactions); a missing get_it registration is a runtime
  error; boundaries are enforced only by code review.
- Revisit if: most use cases are pass-throughs (allow Blocs to use repositories
  directly); a second app needs the protocol (extract `core/protocol` into a package);
  boundary violations appear in review (add import lint rules or split into packages).

## Evidence
None yet; this is a structural decision. The BLE spike (ADR-0002) may change the
transport implementation but not this structure.
