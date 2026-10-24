# October 2026 MoonBit Hackathon requirements check

**Checked:** 2026-10-25. This records only information visible on the [official 2026 hackathon site](https://moonbitlang.github.io/Hackathon2026/). The supplied [formal charter](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd) and [supplementary event page](https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd) could not be retrieved in this session, so the formal charter remains the final authority where available.

## Official hard requirements visible on the current site

| Item | Current official-site wording/meaning | MoonFeature status |
|---|---|---|
| Registration and acceptance deadline | The October round closes on **2026-10-31** for both registration and acceptance. The visible page gives a date but no time of day. | Plan for submission before the date; exact cutoff time is **待确认** in the formal charter. |
| Registration submissions and edits | Up to three submissions in October. The last valid submission or edit before approval determines the effective registration time; a project that has not passed review may be modified. | Keep the form submission count and review state with the participant; form is not submitted by this repository work. |
| Team size | No more than three members; the captain confirms team size and GitHub IDs. | This repository work has one configured contributor; participant/team declaration remains an application step. |
| Application material | Submit participant/project information, a public repository, and a one-page project description. | Proposal draft is in `docs/hackathon-proposal.md`; public URL is pending local acceptance and later remote creation. |
| Acceptance artifact | Submit code, README, tests, and reproducible demo instructions. | Implemented locally; the demo and exact command are documented in `README.md`. |
| Project language and work | MoonBit must be the primary implementation language. An existing project must contain substantive work completed during this round. | New MoonBit-first repository; the current source and commit history are local pending remote publication. |
| Open-source compliance | Use a recognized open-source license and explain port/reference sources. | Apache-2.0; upstream behavioral references and original implementation/test-data provenance are recorded in `docs/sources.md`. |
| Public development history | Keep continuous, traceable public commits and development records; the page also names Issues, PRs, and updates as records to retain. | Local history currently has meaningful, correctly attributed commits; public history is pending repository creation. |
| AI-assisted work | AI tools are allowed, but the participant must understand and explain technical decisions and own final quality. | Design, limitations, tests, and provenance are documented; the participant should review and be prepared to explain them. |
| Non-qualifying work | Duplicated, split, or merely lightly modified projects do not qualify. | MoonFeature is maintained as one SDK project; its conformance limits and original scope are stated explicitly. |
| Event group | Participants must join the event group and use their GitHub ID as the group nickname or prize payment may be affected. | This is a participant-side action; not performed by this local repository. |

## Official suggestions visible on the site

- Suggested project areas include libraries/protocols, data tools, AI applications, and developer tools; the list is not restrictive.
- Prefer a clear scope that can be delivered and validated within roughly one month. The site says the project need not be large and emphasizes usefulness, reliable tests, complete documentation, and maintainability.
- New projects and substantial maintenance of existing MoonBit projects are both allowed; copied/split/lightly changed projects are excluded.

## Items not confirmed by the retrievable official pages

The official page does not visibly show a last-updated timestamp. The official browser extraction returned no page body for the site itself, although the search index exposed current page text and the October 31 date. The two supplied Feishu pages were inaccessible to the web reader. Therefore confirm these points against the formal charter or an organizer notice before form submission:

- Exact submission cutoff time/time zone and the charter's effective version/update time.
- Accepted repository hosting platforms. The site requires a public repository and refers to GitHub IDs, but the retrieved text does not explicitly state that GitHub is the only accepted host.
- Whether a Mooncakes release, a CI workflow, a specific MoonBit version, a specific test matrix, or a PDF-only one-page proposal is mandatory. None is stated in the retrieved acceptance checklist.
- Detailed review criteria, review SLA, modification limits beyond the three October submissions, and any additional declaration fields.

Do not infer these missing requirements from earlier hackathon rounds. The project uses the current stable toolchain and has CI as a quality measure even though those are not confirmed as hard requirements here.

## Participant quality goals for this project

These are project goals, not quoted contest rules:

- At least 3,000 authored MoonBit source lines across runtime, examples, and tests, without padding; the local audit records 4,128 physical `.mbt` lines and 3,348 nonblank, non-comment source lines.
- More than ten meaningful commits by the actual contributor, with the account author `Zcxssxx`; no empty or manufactured commits.
- Four supported MoonBit backends in the local test matrix, a warning-denying CI workflow, and a real native demo.
- Clear disclosure of OpenFeature-inspired behavior and unsupported areas; no unsupported claim of full conformance.
