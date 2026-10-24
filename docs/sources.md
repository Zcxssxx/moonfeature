# Source and provenance

The initial MoonBit implementation, tests, examples, and synthetic feature-flag data are authored for this repository. No upstream SDK implementation or third-party test corpus is copied or vendored.

OpenFeature specification pages are normative behavioral references. They are linked in the design document and will be mapped to implementation and tests in `docs/conformance.md`. The OpenFeature specification itself is not included as source code.

Runtime dependencies are MoonBit core packages only: `moonbitlang/core/ref` for isolated mutable API/provider state and `moonbitlang/core/encoding/utf8` for stable cross-target rollout hashing. No external Mooncakes package, vendored implementation, or third-party fixture is used. Reassess this record whenever a dependency or external fixture is added; record its exact upstream URL, version, license, and the files that use it.
