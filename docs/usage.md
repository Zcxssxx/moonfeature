# Using MoonFeature

MoonFeature is still under active development and has not been published to Mooncakes. The runnable example is the current API reference: [`cmd/demo/main.mbt`](../cmd/demo/main.mbt).

## API and provider setup

Use `Api::new()` when an application or test needs isolated provider, context, hook, and event state. `Api::global()` returns the process-wide shared API handle. The runnable [demo](../cmd/demo/main.mbt) shows validated config creation, conversion to `&Provider`, provider registration, and error handling.

Configuration construction validates non-empty, unique flag keys, rule and rollout value types, non-empty condition attributes, and rollout percentages in the inclusive range 0–100. Provider registration returns a typed `Result`; check it in application setup code before serving requests.

## Evaluation and details

MoonFeature exposes typed value and detailed methods for Boolean, Number, String, and JSON flags. In a function where `client` has already been initialized, an evaluation looks like this:

```mbt
let context = @moonfeature.EvaluationContext::empty()
  .with_targeting_key("user-0")
  .with_attribute("country", @moonfeature.FlagValue::String("CA"))
let details = client.get_boolean_details(
  "checkout-redesign",
  false,
  context,
)
println(details.value().to_repr().to_string())
match details.variant() {
  Some(variant) => println(variant)
  None => ()
}
```

The current base methods take an explicit `EvaluationContext`; there is no overload that omits it.

If no provider is bound, a flag is missing, a provider returns an error, a before/after hook fails, or the provider returns the wrong value type, the client returns the supplied default. Detailed results include the flag key, value, optional variant and reason, and optional error category/message. The SDK does not log evaluation calls.

## Context precedence

Evaluation merges contexts in this order, with later values replacing earlier values:

1. API context
2. Client context
3. Invocation context
4. Context overlays returned from before hooks, in API → Client → invocation → Provider hook order

The merge is per call and does not mutate the source contexts. MoonFeature does not implement transaction-context propagation in this release.

## Local rules and rollout

Rules are evaluated in declaration order. Every condition in a rule must match; the first matching rule wins. Equality compares typed `FlagValue`s, while existence checks that an attribute is present. Rules run before the optional percentage rollout. If neither a rule nor rollout selects a value, the configured flag fallback is returned.

Rollout identity comes from `EvaluationContext.targeting_key`; a rollout that reaches evaluation without a targeting key returns `InvalidContext`. The stable bucket uses UTF-8 bytes of `flag_key + NUL + targeting_key`, starts with `h = 2166136261 mod 2147483647`, and updates for each byte with `h = (h * 16777619 + byte) mod 2147483647`. The bucket is `h mod 10000`; a user is included when `bucket < percentage * 100`. This is a deterministic targeting hash, not a cryptographic hash.

The application owns config updates. Construct and validate a new `Config`, then call `LocalProvider::replace_config`; the provider swaps its in-memory snapshot before emitting `ConfigurationChanged`. The event currently reports the broad change with an empty changed-flag list because the provider does not calculate a per-key diff.

## Hooks

Register hooks with `Api::add_hook`, `Client::add_hook`, `EvaluationOptions::with_hook`, or return them from `Provider::evaluation_hooks`. Before callbacks run API → Client → invocation → Provider, in registration order. After, error, and finally callbacks unwind Provider → invocation → Client → API, reversing order within each scope.

Each evaluation creates fresh JSON data from a hook's data factory. A before callback returns context changes and its updated data; the same hook data is passed to that hook's later callbacks. `EvaluationOptions::with_hints` supplies detached per-call hint data. Hook callbacks report expected failures as `Result`s. A before failure skips provider evaluation and later before/after callbacks; a resolution or after failure returns the caller default and runs error/finally stages. Error and finally callback failures are recorded by the API and do not stop later callbacks in that stage. Use `Api::drain_hook_errors` to retrieve those contained errors.

## Domains, lifecycle, and events

`Api::set_provider_for_domain` binds a provider to a named Client domain; a domain without a binding falls back to the default provider. A domain-scoped provider instance can serve only one domain. New providers initialize before a binding becomes active; a failed initialization keeps the prior binding. Providers are shut down after their last binding is removed, or when `Api::shutdown` resets the API.

API event handlers receive events from all providers registered to that API. Client handlers receive events only from the provider currently selected for that Client's domain, including default-provider fallback. Each event has a kind, optional message and error code, changed flag list, and the provider metadata name added by the API dispatcher. Handler failures are contained and available through `Api::drain_event_handler_errors`.

## Supported profile and limits

The core is synchronous. Providers must resolve from local state and must not block on network work. Custom context values are Boolean, Number, String, or JSON; the OpenFeature datetime custom value is not implemented. Context APIs provide lookup by key but not an all-attributes iterator. Error and resolution-reason enums intentionally expose a fixed subset rather than every OpenFeature extensibility case. See the [conformance matrix](conformance.md) before relying on behavior outside the tested profile.
