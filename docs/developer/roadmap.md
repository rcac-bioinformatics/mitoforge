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
- **Renaming FASTA headers to the sample name.** The finished mitogenome keeps the
  contig name MitoHiFi gave it, e.g. `>ptg000001l.rc.rotated.rotated.rotated_rotated`.
  For a phylogenetic analysis across a hundred samples you want `>ilDeiPorc1` instead.
  Doing it properly means renaming in the FASTA, the GenBank file and the GFF together.
- **A `test_full` profile.** Would need a real, sizeable public dataset and somewhere to
  run it.

## Worth reporting upstream

Two things found while building this pipeline that belong in nf-core/modules or in
MitoHiFi itself, not here:

- **nf-core/modules, mitohifi/mitohifi.** The module staged its inputs flat, next to
  where MitoHiFi writes its own output. Both the contigs input and the reference can be
  called `final_mitogenome.fasta` - the first when contigs mode is handed the output of
  reads mode, the second when one sample's finished mitogenome is the reference for
  another. MitoHiFi then opens the staged symlink for writing and overwrites the file in
  the upstream task's work directory. mitoforge carries a patch that stages them into
  `input/` and `reference/`; the fix belongs upstream.
- **GetOrganelle.** It exits `0` when its seed file is unusable - it prints
  `ERROR: <seed> is empty!` and then returns success. Nothing downstream can tell that
  apart from "ran fine, found nothing": the nf-core module's `fasta` output is optional,
  so the channel is simply empty and the sample disappears. mitoforge's SUMMARY catches
  it and reports `failed: assembly`, which is the right answer, but a non-zero exit
  would let Nextflow report it properly and immediately.
- **MitoHiFi.** `src/getGenesList.py` reads `/gene=` off every CDS in the reference
  GenBank file, and raises `KeyError: 'gene'` if a CDS has none. Plenty of real
  mitogenome submissions annotate CDS features with `/product=` only - the bank vole
  RefSeq record NC_024538 is one - and MitoHiFi then dies on its very last step, after
  it has already written the finished mitogenome. A pre-flight check on the reference,
  or falling back to `/product=`, would save people a whole run. Until then, see the
  troubleshooting page.

## Deliberately out of scope

- Reimplementing any wrapped tool. If a tool is wrong, fix it upstream or swap it out.
- Nuclear genome assembly. Other pipelines do that.
