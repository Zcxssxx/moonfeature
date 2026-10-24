# MoonFeature

MoonFeature is a MoonBit server SDK for typed feature-flag evaluation. It provides isolated APIs, explicit evaluation contexts, pluggable providers, lifecycle and event handling, scoped hooks, and a deterministic in-memory rules provider.

**Status:** early development for the October 2026 MoonBit hackathon. The public API may still evolve. MoonFeature is OpenFeature-inspired and does not claim full OpenFeature conformance; see the [conformance profile](docs/conformance.md).

## Run the demo

With the stable MoonBit toolchain installed:

```sh
moon run cmd/demo --target native
```

The demo evaluates a 70% checkout rollout and a country rule, replaces the caller-owned config, receives the configuration event, and evaluates both users again. Its output is deterministic:

```text
initial rollout and country targeting:
user=user-0 country=CA checkout=Boolean(true) checkout_variant=checkout-canary accent=String("teal") accent_variant=canada-accent
user=alice country=US checkout=Boolean(false) checkout_variant=- accent=String("blue") accent_variant=-
caller replaces config to disable the rollout:
provider event: ConfigurationChanged
user=user-0 country=CA checkout=Boolean(false) checkout_variant=- accent=String("teal") accent_variant=canada-accent
user=alice country=US checkout=Boolean(false) checkout_variant=- accent=String("blue") accent_variant=-
```

## Capabilities

- Boolean, Number, String, and JSON values with detailed resolution results and caller-default fallbacks.
- Context precedence from API to Client to invocation, with before-hook overlays at highest precedence.
- Default and domain provider binding, initialization-before-swap, status, shutdown, and event routing.
- API, Client, invocation, and Provider hooks with ordered stages and per-evaluation hook data.
- Validated local flag configs, first-match rules, equality/existence conditions, stable percentage rollouts, and in-memory updates.

The SDK and local provider run on wasm, wasm-gc, JavaScript, and native targets in the current test matrix. The CLI demo runs on native. The local provider is synchronous and in-memory: it does not include a remote control plane, persistence, vendor adapters, or an administration UI.

## Project guides

- [Usage and behavior](docs/usage.md)
- [Conformance profile and known gaps](docs/conformance.md)
- [Source and provenance](docs/sources.md)
- [Hackathon requirements check](docs/hackathon-requirements.md)
- [One-page project description](docs/hackathon-proposal.md)
- [Approved design](docs/superpowers/specs/2026-10-24-openfeature-sdk-design.md)

## Local checks

From the repository root, run:

```sh
moon fmt --check
moon check --target all --deny-warn
moon check local --target all --deny-warn
moon test --target all --deny-warn
moon test local --target all --deny-warn
moon build --target all --deny-warn
moon build local --target all --deny-warn
moon run cmd/demo --target native --deny-warn
moon info --target all
moon info local --target all
```

The module is licensed under [Apache-2.0](LICENSE). No Mooncakes release has been published from this repository.
