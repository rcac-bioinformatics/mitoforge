//
// INPUT_CHECK: turn samplesheet rows into meta maps.
//
// nf-schema has already checked every cell's type and format by the time rows get
// here. What is left are the rules a JSON schema cannot express: "exactly one of
// fastq_1 or bam", "a reference or a species, not neither", "hifi:<sample> must name
// a hifi sample that exists". Those are checked here, all of them at once, and every
// message names the row and the column so a novice can go straight to the cell.
//

workflow INPUT_CHECK {

    take:
    ch_rows              // channel: [ meta, fastq_1, fastq_2, bam, ref_fa, ref_gb ]
    default_genetic_code // value:   params.genetic_code, used when the column is blank

    main:

    // The whole sheet is validated in one pass so that the user sees every problem at
    // once instead of fixing one row per run. Samplesheets are small; this is cheap.
    //
    // error() is called here rather than inside checkSamplesheet, because an exception
    // thrown inside a called method reaches Nextflow wrapped in an
    // InvocationTargetException and the message is lost.
    def ch_samples = ch_rows
        .toList()
        .flatMap { rows ->
            def (samples, problems) = checkSamplesheet(rows, default_genetic_code)
            if (problems) {
                error(
                    "Found ${problems.size()} problem${problems.size() == 1 ? '' : 's'} in the samplesheet:\n\n" +
                    problems.collect { problem -> "  - ${problem}" }.join('\n') +
                    "\n\nEvery column is explained at https://rcac-bioinformatics.github.io/mitoforge/samplesheet/\n"
                )
            }
            samples
        }

    emit:
    samples = ch_samples // channel: [ meta, [ reads ] ]
}

//
// Check the whole samplesheet. Returns [ samples, problems ], where samples holds one
// [ meta, files ] tuple per row and problems holds every complaint found.
//
def checkSamplesheet(rows, default_genetic_code) {

    def problems = []
    def seen_at = [:]
    def hifi_ids = [] as Set
    def samples = []

    rows.eachWithIndex { row, index ->

        // Row 1 of the file is the header, so the first data row is row 2.
        def line = index + 2
        def (meta, fastq_1, fastq_2, bam, ref_fa, ref_gb) = row
        def id = meta.id
        def where = "row ${line} (sample '${id}')"

        if (seen_at.containsKey(id)) {
            problems << "${where}: column 'sample' repeats a name already used on row ${seen_at[id]}. Sample names must be unique."
        }
        seen_at[id] = line

        //
        // Reads: exactly one of fastq_1 or bam
        //
        if (!fastq_1 && !bam) {
            problems << "${where}: no reads. Fill in column 'fastq_1' (and 'fastq_2' for Illumina), or column 'bam' for an unaligned PacBio BAM."
        }
        if (fastq_1 && bam) {
            problems << "${where}: columns 'fastq_1' and 'bam' are both filled in. Give the reads one way or the other, not both."
        }

        //
        // Platform-specific read layout
        //
        if (meta.platform == 'hifi') {
            if (fastq_2) {
                problems << "${where}: column 'fastq_2' must be empty for a hifi row. HiFi reads are single-ended."
            }
            hifi_ids << id
        }
        if (meta.platform == 'illumina') {
            if (bam) {
                problems << "${where}: column 'bam' is only for PacBio HiFi. Give Illumina reads in 'fastq_1' and 'fastq_2'."
            }
            if (fastq_1 && !fastq_2) {
                problems << "${where}: column 'fastq_2' is empty. mitoforge needs paired-end Illumina reads."
            }
        }

        //
        // Reference: files, or a species to look one up by, or another sample's assembly
        //
        def from_hifi = ref_fa ? ref_fa.startsWith('hifi:') : false

        if (!ref_fa && !meta.species) {
            problems << "${where}: no reference. Fill in both 'ref_fa' and 'ref_gb', or put a scientific name in 'species' and one will be fetched from NCBI."
        }
        if (ref_gb && !ref_fa) {
            problems << "${where}: column 'ref_gb' is filled in but 'ref_fa' is empty. Give both or neither."
        }
        if (ref_fa && !from_hifi) {
            if (!ref_gb) {
                problems << "${where}: column 'ref_gb' is empty. A reference FASTA needs the matching GenBank file, which is where the gene annotation comes from."
            }
            if (!file(ref_fa).exists()) {
                problems << "${where}: column 'ref_fa': file not found: ${ref_fa}"
            }
        }
        if (ref_gb && !file(ref_gb).exists()) {
            problems << "${where}: column 'ref_gb': file not found: ${ref_gb}"
        }
        if (from_hifi) {
            if (meta.platform == 'hifi') {
                problems << "${where}: column 'ref_fa': 'hifi:<sample>' is only for illumina rows. A hifi sample cannot be assembled against another sample's assembly."
            }
            if (ref_gb) {
                problems << "${where}: column 'ref_gb' must be empty when 'ref_fa' is '${ref_fa}'. The GenBank file comes from that sample's own finished mitogenome."
            }
        }

        //
        // Build the meta map. ref_fa and ref_gb stay as the strings the user wrote;
        // PREPARE_REFERENCE replaces them with the resolved files.
        //
        def sample_meta = meta + [
            genetic_code: meta.genetic_code ?: default_genetic_code,
            species:      meta.species ?: null,
            ref_fa:       ref_fa ?: null,
            ref_gb:       ref_gb ?: null,
            ref_source:   from_hifi ? 'hifi' : (ref_fa ? 'file' : 'species'),
            single_end:   meta.platform == 'hifi',
            input_type:   bam ? 'bam' : 'fastq',
        ]

        def files = bam ? [ bam ] : (fastq_2 ? [ fastq_1, fastq_2 ] : [ fastq_1 ])
        samples << [ sample_meta, files ]
    }

    //
    // Cross-row check: every 'hifi:<sample>' must point at a hifi row in this sheet.
    //
    samples.eachWithIndex { sample, index ->
        def meta = sample[0]
        if (meta.ref_source != 'hifi') {
            return
        }
        def target = meta.ref_fa.substring('hifi:'.length())
        def where = "row ${index + 2} (sample '${meta.id}')"
        if (!seen_at.containsKey(target)) {
            problems << "${where}: column 'ref_fa': '${meta.ref_fa}' names sample '${target}', which is not in this samplesheet."
        }
        else if (!hifi_ids.contains(target)) {
            problems << "${where}: column 'ref_fa': '${meta.ref_fa}' names sample '${target}', which is not a hifi sample. Only a hifi sample produces a mitogenome that others can use as a reference."
        }
    }

    return [ samples, problems ]
}
