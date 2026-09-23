# mitoforge documentation

The documentation is published at <https://rcac-bioinformatics.github.io/mitoforge/>.

The pages themselves live in [`src/content/docs/`](../src/content/docs/), which is
where [Starlight](https://starlight.astro.build) expects them. They are ordinary
Markdown, so they read fine on GitHub too.

To build the site locally:

```bash
npm install
npm run dev      # http://localhost:4321/mitoforge/
npm run build    # writes dist/
```

`astro.config.mjs` in the repository root defines the sidebar. Adding a page means
adding the file under `src/content/docs/` and a line to that sidebar.
