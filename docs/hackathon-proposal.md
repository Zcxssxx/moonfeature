# MoonFeature — October 2026 project description

**Applicant/project:** MoonFeature, an open-source feature-flag evaluation SDK for MoonBit server applications.

## Need and users

MoonBit backend developers who need to release features gradually or target behavior by user attributes currently have to define application-specific flag APIs and provider wiring themselves. MoonFeature provides a small reusable contract so applications can evaluate typed flags without coupling their application code to one flag service. The first implementation also gives contributors a deterministic local provider for tests and demonstrations.

## Deliverable

MoonFeature is a synchronous MoonBit SDK with isolated API instances, typed Boolean/Number/String/JSON evaluation, explicit evaluation contexts, pluggable providers, provider lifecycle and domain binding, events, scoped evaluation hooks, and an in-memory rules provider. The local provider supports validated ordered rules, equality/existence conditions, stable percentage rollout, and caller-owned configuration replacement.

The runnable version demonstrates a 70% checkout rollout and a country-targeted accent flag, prints resolution variants, updates the configuration, receives the provider event, and re-evaluates both users. Run it with:

```sh
moon run cmd/demo --target native
```

## Engineering and validation

Implementation and synthetic test data are authored for this project. The SDK runs its current tests on wasm, wasm-gc, JavaScript, and native targets. The repository includes an Apache-2.0 license, a use guide, a source/provenance record, a behavior-to-test profile, and a CI workflow. AI assistance was used for design, implementation, tests, and documentation; code and claims are reviewed against compiler output, tests, and the linked behavioral references, and the participant is responsible for explaining the technical choices.

## Scope and next steps

MoonFeature is OpenFeature-inspired and does not claim full specification conformance. The current release is synchronous and in-memory; it does not include remote providers, persistence, a control plane, or an operator UI. The conformance profile identifies known gaps. Future work can add separately testable standard value/context behavior, provider adapters, persistence, and stronger conformance without changing the project into a hosted service.

**License:** Apache-2.0. **Public repository:** [github.com/Zcxssxx/moonfeature](https://github.com/Zcxssxx/moonfeature). Submit this URL through the event form. **Formal charter details still requiring confirmation:** see [`hackathon-requirements.md`](hackathon-requirements.md).
