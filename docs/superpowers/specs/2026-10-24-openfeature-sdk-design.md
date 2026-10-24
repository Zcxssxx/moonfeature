# MoonFeature — OpenFeature Server SDK Design

MoonFeature is the working project name.

- Status: approved by the user on 2026-10-24; implementation active from 2026-10-25.
- Project directory: `moonfeature/` (independent local Git repository; no remote).
- Intended module: `Zcxssxx/moonfeature`.

## Purpose

Build a reusable, vendor-neutral OpenFeature SDK for MoonBit server applications. A local rules provider will make the SDK runnable without a vendor account or network service. The project implements the OpenFeature concepts in MoonBit from the published specification; it will not copy another SDK implementation.

## Users and complete use scenarios

1. **Gradual rollout:** a service calls a typed flag API with the request's user context. A local provider consistently places a configured share of users into a new checkout variant. The service can keep its control flow independent of the flag provider.
2. **Incident kill switch:** a running service updates the local provider configuration through an application-owned administration path, and subsequent requests evaluate the flag to disable a costly feature without redeploying the binary. This project supplies the SDK and provider seam; the application must supply that administration path. The project does not supply an operator dashboard or remote control plane.
3. **Deterministic tests:** application tests construct an isolated API instance and local provider, evaluate the same flags for different contexts, inspect resolution details, then dispose/reset the instance without leaking state to parallel tests.
4. **Provider migration:** an application depends on the stable SDK API and can later replace the local provider with an adapter while keeping feature evaluations in business code unchanged. The first release provides the provider contract, not vendor adapters.

## Goals

- Provide typed flag evaluation for boolean, number, string, and structured values.
- Preserve resolution detail: flag key, resolved value, variant/reason where supplied, metadata, and error information.
- Follow OpenFeature server-side dynamic-context merging: global API context, client context, invocation context, then context changes made by before hooks; higher levels overwrite duplicate keys.
- Bind default and domain-scoped providers to clients whose immutable metadata identifies their domain; an unbound domain falls back to the default provider.
- Make evaluation calls fail safe: return the caller's default value on missing flags, provider errors, or type mismatch, and report the reason in detailed results.
- Provide isolated API instances for applications/tests and a default API entry point.
- Define a provider contract, initialization/shutdown lifecycle, observable status and events, and ordered evaluation hooks.
- Provide a local in-memory rules provider with equality/existence conditions and deterministic percentage rollout keyed by the flag and targeting key.
- Include a runnable example, tests for core semantics, practical documentation, CI configuration, and complete license/provenance notes.

## Non-goals for the first release

- A hosted feature-flag control plane, administration UI, database, or user management.
- Commercial vendor integrations or network refresh protocols.
- Implicit transaction context propagation through task-local or async runtime state.
- Client-side browser SDK, UI framework integration, or frontend hooks.
- Evaluation of arbitrary user-provided code or expression languages.
- A claim of complete OpenFeature conformance until every applicable normative requirement has a checked implementation/test row.

## Architecture and boundaries

### Core SDK package

Own the public `Api`, `Client`, evaluation context/value types, typed evaluation and detail types, provider interface, domain-to-provider binding, provider lifecycle/status/events, and hook interface. Keep evaluation behavior in MoonBit and independent of HTTP, filesystem, UI, and vendor libraries. Use explicit contexts so a caller can see which data is used for a flag decision.

The default API entry point provides familiar process-wide usage. `Api::new()` is the isolated API factory for dependency injection, services that need different providers, and tests; compiler review may adjust the identifier to MoonBit naming conventions while preserving this behavior. Clients carry an immutable optional domain and use that domain's provider when registered, otherwise the default provider. A provider may declare itself domain-scoped; the API rejects binding that instance to more than one domain. Provider bindings are replaced atomically after successful initialization with the current global context and optional bound domain; providers no longer used by any binding are shut down. API shutdown asks each registered provider instance to shut down once, resets API-owned state even if shutdown reports an error, and restores no-op behavior. Before implementation, the stable-toolchain review must validate a safe one-time mechanism for the process-wide default API; it must preserve independent state for every `Api::new()` instance.

Evaluation and provider lifecycle calls are synchronous in the first release and must be non-blocking. Providers that fetch remote configuration should refresh/cache it outside evaluation and resolve from local state; providers requiring async initialization are outside the first-release provider profile. This keeps the core independent of an async runtime and makes the local provider predictable across supported backends.

Provider events use the OpenFeature event types for ready, error, configuration changed, stale, reconciling, and context changed. API-wide and client-level handlers can be added and removed; event delivery follows the provider bound to each client domain, and one handler failure cannot prevent later handlers from running. Client status reflects provider initialization, error/fatal, stale, and shutdown transitions. The local provider emits ready on successful initialization and the relevant configuration-changed event after an update. A client can query the metadata of its associated provider; API metadata lookup supports an optional domain and falls back to the default provider.

### Local rules provider

Store typed flag definitions and ordered rules in memory. Each rule matches a bounded set of context predicates and returns a typed variant. Percentage rollout uses a documented stable hash of flag key plus targeting key; a missing targeting key cannot silently be treated as a stable user identity. Invalid configurations fail during provider setup with typed errors rather than being hidden by evaluation fallback.

### Example command

A native command demonstrates a checkout flag with named variants and a percentage rollout. It evaluates a small set of explicitly supplied sample contexts and prints values plus resolution details. The example is instructional test data, not a benchmark or claim about production usage.

### Repository structure target

- Root module/package: public SDK surface and documentation.
- `local/`: in-memory rule provider and matching/rollout logic.
- `cmd/demo/`: runnable native scenario.
- `docs/`: design, conformance matrix, usage and provenance.
- Package-local MoonBit tests and fixtures written specifically for this project.

Exact file names and package import edges belong in the implementation plan after specification review.

## API and behavior decisions

- `EvaluationContext` has an optional targeting key and uniquely keyed custom values. Custom values distinguish booleans, numbers, strings, UTC datetimes (represented as epoch milliseconds), and JSON-like structures.
- Structured flag values use MoonBit's JSON value model. Unsupported conversions are reported as type mismatch and return the supplied default.
- Typed convenience methods return values; corresponding detailed methods return a resolution record. Evaluation methods do not raise provider errors to application control flow. Provider setup, configuration validation, and lifecycle operations return typed errors.
- Context merge order is global < client < invocation < before-hook result. The merge is per evaluation; it does not mutate the source contexts.
- Hooks can be registered at API, client, invocation, and provider scope. `before` hooks run from broader to narrower scope, then in registration order within a scope. `after`, `error`, and `finally` hooks unwind from provider to API scope, then in reverse registration order within a scope. Hook data is private to one hook invocation and is shared across that hook's stages; the same read-only hook hints are passed to each hook.
- A hook receives the flag key and type, merged evaluation context, default value, and per-hook data. Before hooks may return context changes that feed later before hooks and are merged at highest precedence. Hook callbacks and event handlers report failures through typed results rather than panicking. A `before` failure stops remaining `before` hooks, skips provider resolution, invokes `error` then `finally` hooks, and returns the supplied default with error details. An `after` failure stops remaining `after` hooks, invokes `error` then `finally`, and returns the supplied default with error details. A provider resolution failure invokes `error` then `finally` and returns the supplied default. Failures from `error` and `finally` hooks are contained so all remaining hooks at that stage run and no hook failure escapes evaluation. These rules follow the OpenFeature hook and evaluation requirements.
- A provider replacement initializes the new provider before switching evaluation to it; after the switch, the prior provider is shut down. If initialization fails, the existing provider remains active. Provider status is observable. The no-provider state uses no-op behavior and returns defaults.
- Local rule evaluation is deterministic for the same flag, context, and configuration across all tested backends. Its hash algorithm and boundary behavior will have published test vectors.

## Error handling and safety

- Distinguish missing flag, type mismatch, invalid context, provider not ready, provider error, and invalid provider configuration in typed errors/details.
- Typed evaluation always returns the given default when the provider cannot return a compatible resolution.
- Redact no data implicitly because the SDK does not log evaluation contexts. Any example hook that logs context must be opt-in and must avoid printing the targeting key by default.
- Validate rollout bounds and rule definitions on construction. Do not panic on user-controlled flag keys or context values.
- Avoid exposing mutable internals through returned details or context snapshots.

## Testing and quality gates

- Write MoonBit tests before implementation for each public behavior, confirm each new behavior test fails for the intended reason, then implement the minimal change and re-run it.
- Derive a requirement matrix from the applicable OpenFeature specification sections and cover context precedence, defaults, typed mismatch, detailed results, provider lifecycle/status, hook order/failure behavior, isolated instances, rule matching, and rollout stability.
- Use project-authored test inputs based on normative behavior. Do not vendor another SDK's code or test suite without a separate provenance and license review.
- Verify with the installed latest stable MoonBit toolchain once its channel status is confirmed. Intended targets are native, JavaScript, wasm-gc, and wasm for the pure core; run the CLI on native. If a target is unsupported by the actual compiler or runtime, document evidence and narrow the declared target matrix rather than claiming support.
- Configure CI to run formatting, warning-denying check/test/build on the supported target matrix, `moon info`, and a check that generated interface files have no unexplained diff.

## License and source provenance

- Project license: Apache-2.0, an OSI-approved license.
- OpenFeature specification and MoonBit toolchain docs are normative/reference sources, not copied implementation code. Cite the relevant spec sections in the conformance matrix and README.
- Design references reviewed on 2026-10-24: [Flag Evaluation API](https://openfeature.dev/specification/sections/flag-evaluation/), [Provider](https://openfeature.dev/specification/sections/providers/), [Evaluation Context](https://openfeature.dev/specification/sections/evaluation-context/), [Hooks](https://openfeature.dev/specification/sections/hooks/), and [Events](https://openfeature.dev/specification/sections/events/). The conformance matrix will record the reviewed specification revision or retrieval date and map each in-scope requirement to implementation and tests. The project will not claim full conformance while any applicable requirement is unimplemented or unverified.
- The first-release profile excludes implicit transaction-context propagation, asynchronous provider lifecycle/evaluation, and optional tracking APIs. These are explicit profile limits, not claims that the OpenFeature specification omits them.
- The initial implementation is original MoonBit code. No upstream implementation, third-party source, or external test data is planned for vendoring. Reassess and record exact project/version/license/source if a dependency or fixture is later added.
- Demo users, flags, and data are synthetic and authored for this repository.

## Development history and scope control

- Preserve real local commit history. Aim for more than 10 meaningful commits by committing completed, independently understandable development steps. No empty commits, timestamp edits, contributor fabrication, or mechanical splitting.
- Keep approximately 3,000 handwritten MoonBit lines as a quality target only; never add code that does not serve the SDK, provider, conformance evidence, example, or maintenance.
- Work only in this new local repository during implementation. No GitHub account inspection, remote creation, push, or other GitHub operation until local development and verification are complete and the user permits the account phase.

## Acceptance criteria for the first runnable version

1. A consumer can create an isolated API, register a local provider, create a client, and evaluate all four value categories with explicit context.
2. Missing flags, incompatible types, provider failures, and missing providers produce safe defaults and useful detailed results.
3. Context precedence, hook order, provider replacement, and per-user percentage rollout are deterministic and tested.
4. Domain-to-provider selection, provider events/status, initialization, replacement, and API shutdown/reset behavior are deterministic and tested.
5. A native demo runs end to end from a documented command.
6. The supported target matrix passes the documented local CI commands, and generated public interfaces are reviewed.
7. README, Apache-2.0 license, CI, source/provenance notes, conformance matrix, and a meaningful commit history are present.

