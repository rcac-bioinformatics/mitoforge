# Roadmap

Ideas that are deliberately **not** in the current version. Nothing here is a promise.
Open an issue before starting on any of it.

## Parked

- **A real ANNOTATE stage.** v1 ships a stub that passes assemblies through unchanged;
  annotation happens inside MitoHiFi's finishing step. A standalone stage (MITOS2, or
  MitoAnnotator for fish) would let people re-annotate without re-assembling. See
  [extending.md](extending.md) for where it plugs in.
- **More assemblers.** `--long_assembler` and `--short_assembler` each accept exactly one
  value today. NOVOPlasty and MITGARD are the obvious short-read additions.
- **Nanopore input.** A third `platform` value with its own assembly subworkflow.
- **Plant and fungal mitogenomes.** MitoHiFi has `-a plant` and `-a fungi`; GetOrganelle
  has `-F embplant_mt`. The pipeline hard-codes the animal path.
- **Chloroplast assembly.** GetOrganelle does `-F embplant_pt` already.
- **Heteroplasmy calling.** v1 publishes `final_mitogenome_choice/` so you can look at
  the alternatives by hand, but it does not quantify variants.
- **NUMT filtering beyond MitoHiFi's own.** Coverage-based screening of the candidate
  contigs.
- **A `test_full` profile.** Would need a real, sizeable public dataset and somewhere to
  run it.

## Deliberately out of scope

- Reimplementing any wrapped tool. If a tool is wrong, fix it upstream or swap it out.
- Nuclear genome assembly. Other pipelines do that.
