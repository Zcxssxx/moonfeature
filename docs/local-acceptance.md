# MoonFeature local acceptance record

**Date:** 2026-10-25 (Asia/Shanghai)

**Scope:** This is the local-only checkpoint recorded immediately before remote creation. Remote publication and hosted CI are tracked separately in `docs/remote-verification.md`.

## Toolchain

`moon version --all` exited 0:

```text
moon 0.1.20261023 (3778465 2026-10-23)
moonc v0.10.17+d971670cd (2026-10-23)
moonrun 0.1.20261023 (3778465 2026-10-23)
```

The local stable self-updater reported the toolchain is up to date. The CI installer resolves the stable toolchain again when the hosted workflow runs.

## Commands and results

| Command | Result |
|---|---|
| `moon fmt --check` | Exit 0. |
| `moon check --target all --deny-warn` | Exit 0. |
| `moon check local --target all --deny-warn` | Exit 0. |
| `moon test --target all --deny-warn` | Exit 0; 33/33 on wasm, wasm-gc, JS, and native. |
| `moon test local --target all --deny-warn` | Exit 0; 6/6 on wasm, wasm-gc, JS, and native. |
| `moon build --target all --deny-warn` | Exit 0; root SDK and demo produced wasm, wasm-gc, JS, and native artifacts. |
| `moon build local --target all --deny-warn` | Exit 0 on all targets. |
| `moon run cmd/demo --target native --deny-warn` | Exit 0; exercised rollout, country rule, config replacement, event delivery, and re-evaluation. Exact output is in `README.md`. |
| `moon info --target all` | Exit 0; generated root interfaces remained unchanged. |
| `moon info local --target all` | Exit 0; generated local-provider interface remained unchanged. |
| `git diff --check` | Exit 0. |
| `git diff --exit-code` after `moon info` | Exit 0; no generated interface changes. |
| `git status --porcelain` after the verification sequence | Empty; clean local working tree. |

The native demo output showed `user-0` receiving `checkout-canary` at 70%, `alice` not receiving the rollout, and both users having the checkout flag disabled after the caller replaces the config with a 0% rollout. The independent Canada accent rule stayed active and the provider emitted `ConfigurationChanged`.

### Registry update limitation

`moon update --verbose --trace` exited 1 with `failed to lock registry update directory` and Windows OS error 5 (access denied) before completing an update. The project currently has no external Mooncakes dependency. The GitHub Actions workflow includes `moon update` on its fresh hosted runner; that step remains unverified until remote CI runs. The diagnostic created an incidental local `trace.json`, which was removed; no credentials or tokens were read.

## Repository audit

- **Structure:** Root MoonBit SDK package; `local/` deterministic rules provider; `cmd/demo/` native consumer; `.github/workflows/test.yml`; usage, conformance, provenance, hackathon requirements/proposal, design, plan, and progress documents. Generated public interfaces are tracked for root, local, and demo packages.
- **README:** Gives the runnable command and observed output, capabilities, target matrix, limitations, documentation links, and local verification commands.
- **License:** Apache-2.0 text with `Copyright 2026 Zcxssxx` notice.
- **History:** More than ten non-empty, purpose-specific local commits. All author and committer entries are `Zcxssxx <298122762+Zcxssxx@users.noreply.github.com>`; no empty, backdated, or synthetic-contributor commits were made.
- **Branch and remote:** Current local branch is `main`; no remote exists yet. A remote default branch, uploaded files/history, remote contributors, and hosted CI status are pending the current-account check and subsequent GitHub operation.
- **MoonBit source scale:** 25 authored `.mbt` files contain **4,128 physical lines**, including **2,534 runtime/demo lines** and **1,594 test lines**. Excluding blank lines and comment-only lines, the source has **3,348 code lines** (1,930 runtime/demo and 1,418 tests). Generated `.mbti`, documentation, and build artifacts are excluded.
- **Provenance:** Implementation and synthetic fixtures were authored for this project. Runtime imports are MoonBit core `ref` and UTF-8 packages only. OpenFeature pages are normative behavior references, not copied implementation or test corpora. Exact upstream links and workflow references are listed in `docs/sources.md`.
- **Placeholders:** `rg -n 'TODO|FIXME|TBD' -g '*.mbt' .` returned no matches. Formal-charter unknowns remain explicitly marked `待确认` in the submission rules record.

## Items outside the local checkpoint

- The later active-identity check, public repository creation/push, remote file/history/contributor audit, and hosted CI are recorded separately in `docs/remote-verification.md`.
- Retrieve the supplied formal charter/supplement through an organizer or accessible source to confirm exact cutoff time, hosting platform, Mooncakes requirement, CI/toolchain mandates, review criteria, and allowed edits. The official site confirms 2026-10-31 but gives no time of day.
- No Mooncakes publication has been made. The official page text retrieved in this session does not say whether publication is required; confirm against the formal charter before deciding.
- The participant must submit the event form and join the official event group using the GitHub ID as nickname; this is not done by the local code work.
