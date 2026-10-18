---
name: dependency-update
description: Update the dependencies of the VGC Gemeinde repos (gemeinde-tours, gemeinde-tippspiel, buli-hub) to their latest versions by hand — npm packages, Docker base images, GitHub Actions and the Supabase CLI — with per-repo verification. Use when asked to update, upgrade or modernise dependencies in any of these repos; it replaces Renovate, which is switched off.
---

# Dependency update

Renovate is off. Updates are deliberate: everything goes to its **latest** version, not just
"in line with the sibling repos", and each repo is verified end to end before a commit.

Repos, under `~/Projects/`:

| Repo | Branch | Remote | Extra |
|---|---|---|---|
| `gemeinde-tours` | `master` | GitHub | static export + nginx image; ingest pipeline |
| `gemeinde-tippspiel` | `master` | GitHub (private) | standalone Next on Cloud Run |
| `buli-hub` | `dev` | GitHub; push to `dev` deploys staging | GitHub Actions, local Supabase stack, Supabase CLI |

Order: smallest first (tours → tippspiel → buli-hub), so a major's surprises show up where
they are cheapest.

## 0. Before touching anything

- Run `ListAgents` and `git status` in each repo. Other Claude sessions work in these repos in
  parallel. **Never `git add -A`**; stage explicit paths only, and leave changes you did not
  make alone. A swept-in file once got pushed to `dev` and broke CI.
- Present a plan before changing anything (all three repos require it): the version table,
  which jumps are majors, and the decisions below.

## 1. Inventory

Per repo: `npm outdated`, `npm audit`, the `FROM` lines in `Dockerfile`, and for buli-hub
`grep -n 'uses:' .github/workflows/*.yml` plus the Supabase CLI pin in `ci.yml` and
`supabase --version`. For every major, read the release notes (`gh api
repos/<owner>/<repo>/releases/tags/<tag> --jq .body`, or a web search) and grep the repo for the
APIs or inputs they break.

## 2. Rules

- **Node follows LTS.** `@types/node` stays on the Docker image's Node major
  (`node:24-alpine` → `@types/node@24`). Move to a new Node major only once it is LTS, and then
  in one step: Dockerfiles, `setup-node` `node-version`, `@types/node`.
- **Exact pins** (`save-exact=true`). Install with
  `npm install --save-exact <pkg>@latest …` (dev dependencies with `-D`), then
  `npm audit fix` — never `--force`.
- **Overrides go stale.** Re-check every `overrides` entry: one held `sharp` on a vulnerable
  version after Next itself required the patched one. Drop the override if the dependency
  chain is fine without it.
- **Audit leftovers** that have no fix and sit only in dev tooling (e.g. `braces` via the
  shadcn CLI, `esbuild` via `drizzle-kit`) are reported, not forced.
- **Base images:** nginx follows its newest line (`nginx:<x.y>-alpine`); no digest pinning
  (pure upkeep without a bot).
- **GitHub Actions:** newest major, after checking that the inputs in use still exist.
- **Supabase CLI** (buli-hub): local binary and CI pin move together. Install from the GitHub
  release, verify `checksums.txt`, keep the old binary as backup. `supabase stop` keeps the data
  volume; `supabase start` on the new CLI restores from it. Apply config renames the CLI warns
  about. Ask before anything that needs `db reset` — it wipes local data.

## 3. Majors that needed care

- **TypeScript 7** (native compiler, no JS API): `next build` type-checks via the CLI since
  Next 16.3. Prove `tsc` still fails on an error by adding a throwaway
  `export const x: number = "a";` file, then delete it. Options removed in TS 7 (e.g.
  `baseUrl`) are errors, not warnings. Fallback: TS 6.
- **Biome minors** add rules and file types. Run `npx biome migrate --write`, then:
  - enable `"css": { "parser": { "tailwindDirectives": true } }` for Tailwind CSS;
  - exclude what is not code: `!**/*.svg`, scraped HTML fixtures, frozen `specs/*/mockups`;
  - fix real findings; where a rule is wrong for the case, use
    `// biome-ignore <rule>: <reason>` with the reason the old comment gave; remove
    suppressions Biome reports as unused;
  - CI runs `biome ci .`, which can disagree with a local `biome check` (it checks the committed
    tree only) — run `biome ci .` before pushing buli-hub.
- **Vitest majors:** mock defaults change (`clearMocks`); buli-hub has the mocks. A CommonJS
  package (`buli-hub` has no `"type": "module"`) needs `vitest.config.mts`.

## 4. Verify each repo

Always: `npm run check`, `npm run typecheck`, `npm test -- --run`, `npm run build`, a Docker
build and a smoke test of the image. Note new build warnings; when one appears, build the
pre-update commit in a temporary `git worktree` to tell regressions from old problems.

- **tours:** `npm run docker:build`, run on a free port, `curl` `/`, the TEAMS/META/TOPCUT
  routes, one `/team/<player>` page and a 404. Re-run
  `npm run ingest -- <slug> --offline` and diff the output against the previous file: only
  `ingestedAt` may change.
- **tippspiel:** `docker build` needs `--build-arg NEXT_PUBLIC_SUPABASE_URL=…
  --build-arg NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=…` (values from `.env`); `/` answers 200,
  protected pages redirect. Check the image holds only runtime files.
- **buli-hub:** tests need the local Supabase stack running (`supabase status`). Image build
  takes the same two build args; run with `--network host --env-file .env`. Routes that 404
  locally because of the season phase (`/spielplan`, `/playoffs`, `/relegation`) are expected.

## 5. Commit and ship

- One commit per repo, only after the maintainer approves; explicit paths; commit message in
  the repo's style (buli-hub: German titles).
- tours and tippspiel: push `master` when approved.
- buli-hub: a push to `dev` runs CI and deploys staging — the only real test of Action bumps.
  Watch it (`gh run watch <id>` in the background) and read failures with
  `gh run view <id> --log-failed`. Re-run a job only when the failure is clearly external.

## 6. Report

A table per repo (tests, build, image, what moved), what changed besides version numbers,
what was found along the way (fix separately, not inside the update commit), and what is
deliberately left for later (e.g. the next Node LTS).
