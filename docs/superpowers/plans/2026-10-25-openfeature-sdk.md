# MoonFeature OpenFeature Server SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable synchronous OpenFeature-style MoonBit server SDK with an in-memory rules provider, runnable demo, behavior tests, CI, and submission-ready documentation.

**Architecture:** Public SDK types and API live in the root MoonBit package. A `local/` package implements deterministic in-memory rules using the public provider contract. A native CLI demo consumes only the public API. Keep evaluation logic explicit-context, synchronous, typed, and vendor-neutral.

**Tech Stack:** MoonBit stable `moon 0.1.20261023`, `moonc v0.10.17+d971670cd`, `moonrun 0.1.20261023`; MoonBit core only unless justified; GitHub Actions workflow drafted locally but no remote write before local acceptance gates.

## Global Constraints

- Module: `Zcxssxx/moonfeature`; local repo `moonfeature/`; unborn `main`; no remote.
- Non-development stable updater completed “up to date”; recheck `moon version --all` before final verification.
- Typed values: Boolean, Number, String, JSON. Errors/mismatches resolve to caller defaults with detail.
- Context precedence: API < client < invocation < before-hook updates.
- Synchronous, non-blocking lifecycle/evaluation and explicit contexts.
- Exclude hosted control plane, vendor/network adapters, implicit async context, browser SDK, and expression language.
- No copied implementation or third-party test data; reference OpenFeature normative sections and write synthetic examples/tests.
- Root license Apache-2.0. Disclose sources, dependencies, and test-data origins.
- About 3,000 useful handwritten `.mbt` LOC is a quality target, never a quota.
- Local commit author is `Zcxssxx <298122762+Zcxssxx@users.noreply.github.com>`; only real, independently reviewable commits.
- Create/push remote only after local implementation and verification pass.

## Planned File Map

- Root: `moon.mod`, `moon.pkg`, `value.mbt`, `context.mbt`, `errors.mbt`, `resolution.mbt`, `provider.mbt`, `api.mbt`, `client.mbt`, `evaluation.mbt`, `hooks.mbt`, `events.mbt`, `lifecycle.mbt`.
- Root tests: `value_test.mbt`, `context_test.mbt`, `evaluation_test.mbt`, `api_test.mbt`, `hooks_test.mbt`, `lifecycle_test.mbt`.
- Local provider: `local/moon.pkg`, `local/config.mbt`, `local/matcher.mbt`, `local/rollout.mbt`, `local/provider.mbt` and matching `*_test.mbt` files.
- Demo: `cmd/demo/moon.pkg`, `cmd/demo/main.mbt`.
- Project docs/release: `README.md`, `LICENSE`, `docs/usage.md`, `docs/conformance.md`, `docs/sources.md`, `.github/workflows/test.yml`.

## Task 1: Buildable module, license, and source identity

**Files:** `moon.mod`, `moon.pkg`, `README.md`, `LICENSE`, `docs/sources.md`, retained design doc.

- [x] Probe `moon new` with supported dry-run against the docs-only project directory; if unsupported for a non-empty directory, create a sibling temporary scaffold and copy only generated metadata. Preserve the design document.
- [x] Run `moon check --deny-warn` to record the empty-module baseline.
- [x] Add Apache-2.0 text and disclose original project-authored implementation, synthetic tests/data, and normative OpenFeature references.
- [x] Mark the approved design as implementation active.
- [x] Verify package identity and commit scaffold once baseline passes.

## Task 2: Typed values, contexts, errors

**Files:** `value.mbt`, `context.mbt`, `errors.mbt`, matching tests.

- [x] Write tests first for each typed value, type mismatch results, context merge replacement/copy behavior, targeting-key precedence, and nested JSON preservation.
- [x] Run focused tests; confirm they fail because symbols are absent.
- [x] Implement `FlagValue`, `ValueType`, `EvaluationContext`, context merge, SDK error categories, and snapshots using compiler-confirmed APIs.
- [x] Run focused tests, `moon check --deny-warn`, and `moon test --deny-warn`; format and commit.

## Task 3: Provider and resolution contract

**Files:** `provider.mbt`, `resolution.mbt`, `provider_test.mbt`.

- [x] Write tests against an intended object-safe `Provider` trait for metadata, initialize/shutdown, status, and typed resolution using a minimal provider.
- [x] Run tests before implementation and confirm expected missing-symbol diagnostics.
- [x] Define provider contract via compiler-verified `&Provider` trait objects; model metadata/status/errors and resolution value, reason, variant, flag metadata, error code/message.
- [x] Test initialization failure and unsupported value type handling.
- [x] Run checks/tests, review `moon info`, and commit contract separately.

## Task 4: Isolated APIs, clients, context layers, typed evaluation

**Files:** `api.mbt`, `client.mbt`, `evaluation.mbt`, `api_test.mbt`, `evaluation_test.mbt`.

- [ ] First write tests for independent `Api::new()` state, no-provider defaults, four typed getters/details, missing flags, type mismatch, and context merge order.
- [ ] Run them and confirm failure before implementation.
- [ ] Implement default API via one `Ref[ApiState]`, isolated API factory, immutable client/domain identity, provider selection, and typed conversion/default behavior.
- [ ] Prove failures preserve caller defaults and diagnostics and isolated APIs do not share provider/context state.
- [ ] Run focused/full tests, inspect `moon info`, commit this layer.

## Task 5: Binding, lifecycle, status, events

**Files:** `lifecycle.mbt`, `events.mbt`, `api.mbt`, `lifecycle_test.mbt`.

- [ ] Write failing tests for default/domain binding, unbound fallback, single-domain restrictions, initialize-before-swap, retaining prior provider on init failure, old-provider shutdown, status, event handler add/remove/delivery, and shutdown/reset despite errors.
- [ ] Run tests and confirm missing behavior failure.
- [ ] Track each provider instance to initialize/shutdown once; route events to API/matching-client handlers; continue after one handler error.
- [ ] Assert order, replacement atomicity, and reset semantics.
- [ ] Run full checks/tests and commit separately.

## Task 6: Scoped hooks and failure behavior

**Files:** `hooks.mbt`, `evaluation.mbt`, `hooks_test.mbt`.

- [ ] First test API/client/invocation/provider scope ordering, context updates, reverse after/error/finally order, per-hook data, and before/after/provider/error/finally failures.
- [ ] Run tests and confirm missing behavior failure.
- [ ] Implement typed callbacks: before/after/provider failures return caller default and invoke error/finally; error/finally failures remain contained while later callbacks at that stage still run.
- [ ] Assert callback trace order and provider-skip behavior after a before failure.
- [ ] Run suite and commit hooks separately.

## Task 7: Deterministic local rules provider

**Files:** `local/config.mbt`, `local/matcher.mbt`, `local/rollout.mbt`, `local/provider.mbt`, provider tests.

- [ ] First write tests for duplicate keys, invalid configuration, rule precedence, equality/existence predicates, typed results, missing flag, and missing rollout targeting key.
- [ ] Freeze stable hash test vectors before implementing rollout; include bucket boundaries plus 0% and 100%.
- [ ] Implement config validation, rule matching, documented stable hash, in-memory config replacement, and configuration-changed event.
- [ ] Run tests on stable supported targets and compare deterministic outputs.
- [ ] Commit validated provider behavior.

## Task 8: Consumer demo and documentation

**Files:** `cmd/demo/moon.pkg`, `cmd/demo/main.mbt`, `README.md`, `docs/usage.md`, `docs/conformance.md`, `docs/sources.md`.

- [ ] Add a tested scenario for a named checkout flag, percentage rollout, details, and caller-owned rule update.
- [ ] Implement demo using public API only; run `moon run cmd/demo --target native` and record output.
- [ ] Document usage, context precedence, errors/defaults, limitations, rollout algorithm, synchronous profile, and conformance boundaries.
- [ ] Map in-scope OpenFeature requirements to source/tests with retrieval date and official links; list dependencies and authored fixtures/data.
- [ ] Commit docs/demo after examples/tests pass.

## Task 9: CI and final local acceptance

**Files:** `.github/workflows/test.yml`, docs/README refinements.

- [ ] Use supplied community workflow examples to install stable MoonBit, print `moon version --all`, update packages, format, check/test/build supported targets with denied warnings, run `moon info`, and inspect generated interface diffs. Use minimum workflow permissions and checkout `persist-credentials: false`.
- [ ] Run in order: `moon version --all`; `moon fmt --check`; `moon check --target all --deny-warn`; `moon test --target all --deny-warn`; `moon build --target all --deny-warn`; native demo; `moon info`; `git diff --check`.
- [ ] Record target limitations from output and narrow target claims if needed; never add unsupported `--deny-warn` to `moon fmt` or `moon info`.
- [ ] Audit structure, README, Apache-2.0, sources/tests/data, examples, generated API, authors/history, default branch, and MoonBit LOC.
- [ ] Record exact results and unresolved issues in `docs/superpowers/logs/`; draft the one-page October proposal. Do not claim remote repository/CI until independently checked.
- [ ] Commit only real final CI/audit changes; proceed to GitHub after local gates pass.

## Self-review

- Spec coverage: values/defaults/details → Tasks 2–4; context → 2 and 4; domain binding/lifecycle/status/events → 5; hooks → 6; local rules/rollout → 7; demo/docs/provenance/conformance → 8; targets/CI/API review/history → 9.
- No TODO/TBD implementation placeholders; results must come from actual commands.
- Type consistency: provider objects are `&Provider`; evaluation takes `EvaluationContext` and returns typed details; local provider implements the same object-safe contract.
- Compiler risks to resolve before public API freeze: callback shapes, context map copy semantics, JSON construction/conversion, provider identity, CLI support, and cross-target availability.

## Execution Notes

- `moon new . --user Zcxssxx --name moonfeature --dry-run` failed because `moon new` explicitly does not support dry-run. Switched to a temporary `_scaffold/` directory, copied only module metadata/license/ignore rules, validated them, then removed `_scaffold/` after confirming its resolved path remained under the project root.
- `moon new` could not create its optional `README.md` symlink on Windows (OS error 1314). The project uses a normal `README.md` instead.
- First `moon fmt --check` caught template formatting differences in `moon.mod` and the empty root package. Ran plain `moon fmt` (without unsupported flags) and the next format check passed.
- Empty-module baseline: `moon check --deny-warn` passed; `moon test --deny-warn` exited successfully with 0 tests and warning “no test entry found”; `moon info` generated the expected empty `pkg.generated.mbti`.

- TDD implementation slice: tests first failed on missing types, then on mutable nested JSON leakage; recursive JSON snapshotting made the targeted tests pass.
- Compiler/tooling corrections: black-box tests use module-qualified paths; public enum construction uses pub(all); derived Eq/Debug methods are explicitly extended; empty maps use Map([]) to keep deny-warn clean.
- moon ide doc still fails with “no metadata is available for any backend” inside this module. Verified JSON/Map/Debug signatures against installed stable core source; implementation uses the published API rather than copying core code.
- Cross-target result: moon fmt --check passed; moon check --target all --deny-warn passed; moon test --target all --deny-warn passed 7/7 on wasm, wasm-gc, JS, and native; moon info --target all generated an intentional public-interface update.

- Provider TDD: the black-box test first failed on the absent trait/types, then passed after defining the object-safe contract. The test also proves runtime dispatch through an actual &Provider value.
- Resolution objects snapshot typed values and JSON metadata; getters return detached data. Trait status and reason enums remain extensible as public SDK concepts.
- Cross-target verification: format/check passed, 8/8 tests passed on wasm, wasm-gc, JS, and native; moon info --target all produced the reviewed provider and resolution interface.
