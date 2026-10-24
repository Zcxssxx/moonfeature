# Remote repository verification

This record separates GitHub evidence from the local acceptance record. All checks here used the `gh` CLI only after `gh api user --jq .login` returned the authorized login `Zcxssxx`.

## First publication snapshot

| Property | Verified value |
|---|---|
| Repository | [Zcxssxx/moonfeature](https://github.com/Zcxssxx/moonfeature) |
| Visibility | Public |
| Default branch | `main` |
| Remote head | `3ba5d201f6c8e052a718023c77d7b36bfa5229eb` |
| First push | `2026-10-24T17:07:24Z` |

- GitHub's recursive tree API returned 45 files on `main`, including the MoonBit root package, `local/` provider, native demo, generated interfaces, tests, Apache-2.0 license, docs, and `.github/workflows/test.yml`.
- The remote commit API returned 14 commits through the first published head. Every commit author is `Zcxssxx <298122762+Zcxssxx@users.noreply.github.com>`.
- The contributors API returned one contributor, `Zcxssxx`, with 14 contributions.

## First hosted CI run

Workflow run [40114687124](https://github.com/Zcxssxx/moonfeature/actions/runs/40114687124) completed successfully for the first published head. The hosted runner reported:

```text
moon 0.1.20261023 (3778465 2026-10-23)
moonc v0.10.17+d971670cd (2026-10-23)
moonrun 0.1.20261023 (3778465 2026-10-23)
```

The remote log confirms `moon update` completed, root tests passed 33/33 on wasm, wasm-gc, JS, and native, and local-provider tests passed 6/6 on those same targets. All-target builds, the native demo, `moon info`, and the generated-interface clean-tree check completed successfully.

The first run reported that `actions/checkout@v4` was forced to Node 24 after Node 20 retirement. The workflow was changed to pin the signed `actions/checkout` v7.0.1 release commit. Follow-up run [40114983566](https://github.com/Zcxssxx/moonfeature/actions/runs/40114983566) completed successfully for head `fc8a3d6173e84c4e30221154b9e720dc448ddf93`; it passed `moon update`, the same 33/33 and 6/6 four-target tests, all-target builds, the demo, and generated-interface cleanliness. Its log had no Node 20 warning.

GitHub added an annotation that `ubuntu-latest` was migrating to Ubuntu 26. The workflow now pins `ubuntu-24.04`. Run [40115073639](https://github.com/Zcxssxx/moonfeature/actions/runs/40115073639) completed successfully for head `54bc211b748af0fc3e50d9d11906335fb22f2c65` on the Ubuntu 24.04 image. It repeated the same successful `moon update`, 33/33 and 6/6 four-target tests, builds, demo, and generated-interface checks. The log confirms Moon 0.1.20261023 / moonc v0.10.17+d971670cd and no checkout Node 20 warning.

## Verified snapshot after runner update

At head `54bc211b748af0fc3e50d9d11906335fb22f2c65`, GitHub reports a public repository with default branch `main` and 46 files on the branch. The commit API lists 16 commits; each commit's linked GitHub author login is `Zcxssxx`. The contributors endpoint lists one contributor, `Zcxssxx`, with 14 contributions, while the commits endpoint lists 16 commits. These are distinct API counts, so the contribution total is not presented as a commit count.

The local branch tracks `origin/main` at the same head, and the local worktree is clean. Subsequent documentation-only commits, if any, require their own remote head and CI checks.
