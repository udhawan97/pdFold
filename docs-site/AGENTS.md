# Orifold docs site

Astro + Starlight documentation site. Independent of the Swift app build — see the root
[CLAUDE.md](../CLAUDE.md) for the app itself.

## Development

```bash
npm run dev --prefix docs-site      # port 4321
npm run build --prefix docs-site    # verify before pushing
```

Claude Code: use `preview_start` with the `orifold-docs` config from `.claude/launch.json`
rather than running a server via bash.

## Deploys

`.github/workflows/docs.yml` deploys to GitHub Pages on push to `main` touching `docs-site/**`.
A daily 06:17 UTC cron re-bakes the download button's version and file size, so a missed
post-release rebuild self-heals within 24h.

## Gotcha

`src/lib/release.ts` (`LAST_KNOWN_GOOD`) and `src/data/stats.json` both hard-code the app
version and must be bumped alongside `project.yml` on every release. They drift
independently and nothing fails when they do:

- `LAST_KNOWN_GOOD` is only read when the GitHub API is unreachable or rate-limited at build
  time, so a stale value stays invisible until the day a build actually needs it.
- `stats.json` numbers (tests, files, loc) are rendered as-is and are currently stale —
  it claims 752 tests / 186 files, against an actual 877 tests / 129 app source files.

## Reference

- [Astro docs](https://docs.astro.build)
- [Starlight docs](https://starlight.astro.build)
- [Content collections](https://docs.astro.build/en/guides/content-collections/)
- [Internationalization](https://docs.astro.build/en/guides/internationalization/)
