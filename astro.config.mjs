// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import starlightThemeNova from "starlight-theme-nova";

// The site is a GitHub Pages project page, so it is served from a subpath.
// `base` has to match the repository name.
export default defineConfig({
    site: "https://rcac-bioinformatics.github.io",
    base: "/mitoforge",
    trailingSlash: "always",
    integrations: [
        starlight({
            plugins: [starlightThemeNova()],
            title: "mitoforge",
            description:
                "Assemble, circularise and annotate animal mitochondrial genomes from PacBio HiFi or Illumina paired-end reads.",
            social: [
                {
                    icon: "github",
                    label: "GitHub",
                    href: "https://github.com/rcac-bioinformatics/mitoforge",
                },
            ],
            editLink: {
                baseUrl: "https://github.com/rcac-bioinformatics/mitoforge/edit/master/",
            },
            lastUpdated: true,
            // Starlight ships Expressive Code, which is Shiki underneath. These are the
            // languages the pipeline's own examples are written in; `groovy` is what
            // Nextflow's .nf and .config files highlight as.
            expressiveCode: {
                themes: ["github-dark-default", "github-light-default"],
                styleOverrides: {
                    borderRadius: "0.4rem",
                    codeFontSize: "0.85rem",
                },
            },
            sidebar: [
                { label: "Home", link: "/" },
                { label: "Quick start", link: "/quick-start/" },
                { label: "Samplesheet", link: "/samplesheet/" },
                {
                    label: "Cases",
                    items: [
                        { label: "Overview", link: "/cases/" },
                        { label: "HiFi with an NCBI reference", link: "/cases/hifi-ncbi-reference/" },
                        { label: "HiFi from a PacBio BAM", link: "/cases/hifi-from-bam/" },
                        { label: "Short reads with your own reference", link: "/cases/short-reads/" },
                        { label: "Short reads using HiFi mitogenomes", link: "/cases/short-reads-from-hifi/" },
                        { label: "Many species at once", link: "/cases/many-species/" },
                        { label: "Heteroplasmy and NUMTs", link: "/cases/heteroplasmy-and-numts/" },
                        { label: "On a laptop with Docker", link: "/cases/laptop/" },
                        { label: "When a sample fails", link: "/cases/failed-sample/" },
                    ],
                },
                { label: "Output reference", link: "/output/" },
                { label: "Troubleshooting", link: "/troubleshooting/" },
                { label: "Citations", link: "/citations/" },
                {
                    label: "Developer guide",
                    items: [
                        { label: "Overview", link: "/developer/" },
                        { label: "Adding a stage", link: "/developer/extending/" },
                        { label: "Adding an assembler", link: "/developer/adding-an-assembler/" },
                        { label: "Adding a cluster profile", link: "/developer/adding-a-cluster-profile/" },
                        { label: "Roadmap", link: "/developer/roadmap/" },
                        { label: "Contributing", link: "/contributing/" },
                    ],
                },
            ],
        }),
    ],
});
