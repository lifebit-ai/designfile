// Re-usable componext for adding a helpful help message in our Nextflow script
def helpMessage() {
    log.info"""
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run main.nf --s3_location  's3://lifebit-featured-datasets/IGV/' --file_suffix 'cram' --index_suffix 'crai' --output_file design_file.csv
    Mandatory arguments:


    """.stripIndent()
}

if (!params.output_file.endsWith('csv')) exit 1, "You have specified the --output_file to be '${params.output_file}', which does not indicate a comma sepearated file.\nPlease specify an output file name with --output_file that ends with .csv"

Channel.fromPath("${params.s3_location}/**.${params.file_suffix}")
       .map { it -> [ file(it).name.minus(".${params.file_suffix}"), "s3:/"+it] }
       .set { ch_files }

Channel.fromPath("${params.s3_location}/**.${params.index_suffix}")
       .map { it -> [ file(it).name.minus(".${params.index_suffix}").minus(".${params.file_suffix}"), "s3:/"+it] }
       .set { ch_indexes }

ch_files_and_indexes = ch_files.join(ch_indexes, by:0, remainder:params.keep_missing)
                    .map {it -> [it[0], it - it[0]] }   // it - it[0] returns array without first element


    process create_design_row {
    tag "file:${name}"

    input:
    set val(name), val(s3_file) from ch_files_and_indexes

    output:
    file "${name}.csv" into ch_rows
    """
    echo "${name},${s3_file.collect {"$it"}.join(',')}" > ${name}.csv
    cat ${name}.csv
    """
    }

    process bind_design_rows {
    publishDir 'results/s3_locations/', mode: 'copy'

    input:
    file(design_rows) from ch_rows.collect()

    output:
    file("${params.output_file}") into ch_design_file
    file("only_indices_${params.output_file}") into ch_indices_only
    file("only_main_files_${params.output_file}") into ch_main_files_only
    file("complete_file_sets_${params.output_file}") into ch_complete_file_sets

    """
    echo "name,file,index" > header.csv
    for row in $design_rows; do cat \$row >> body.csv; done
    cat header.csv body.csv > ${params.output_file}

    # Creating the lists of files that contain only files without indices, only indices, and only complete sets.

    echo "name,index"      > only_indices_${params.output_file}
    echo "name,file"       > only_main_files_${params.output_file}
    echo "name,file,index" > complete_file_sets_${params.output_file}

    # Mathcing the pattern. Logic:
    # 1. In order to match extesion, we need to escape the dot with backsalsh in grep. In order to get backsalsh to grep from nextflow, we need to escape it again in nextflow, which leads to two backsalshes.
    # 2. -v argument for grep allows inverted match, to find all lines that DON'T have eg the index to report as all files without indexes, and vice versa.
    # 3. The comma ',' after search param in first and third line is important. Since often index files contain both file and index sufixes (like .bam.bai) inverted matching for
    # just file suffix would still match cases .bam.bai for '.bam' even if only index is present and fail to report this one as index-ony.
    # Comma after the file suffix allows to only look for files, because in the body.csv filenames are second column which are always followed by index column even if its empty.
    # And since columns in csv are always separated by comma, looking for '.bam,' instead of '.bam' will never match index '.bam.bai'.
    # 4. The '|| true' part is needed to avoid exit code 1 which grep gives if there are no matches. Without '|| true' nextflow porcess would immediately fail in case if all files have all indices.

    cat body.csv | { grep -v '\\.${params.file_suffix},' || true; } | cut -f1,3 -d"," >> only_indices_${params.output_file}
    cat body.csv | { grep -v '\\.${params.index_suffix}' || true; } | cut -f1,2 -d"," >> only_main_files_${params.output_file}
    cat body.csv | { grep '\\.${params.file_suffix},' || true; } | { grep '\\.${params.index_suffix}' || true; } >> complete_file_sets_${params.output_file}
    """
    }

if (params.stage_files) {

    ch_main_files_only
        .splitCsv(sep: ',', skip: 1)
        .map { name, main_file -> [ name, file(main_file) ] }
        .set { ch_main_files }

    process stage_main_files {
    tag "id:${name}"
    publishDir "results/staged_files_checksums/main_files_only/"

    input:
    set val(name), file(file_path) from ch_main_files

    output:
    file("${name}_main_files_only_md5sum.txt") into ch_main_files_lists

    script:
    """
    md5sum *${params.file_suffix} > "${name}"_main_files_only_md5sum.txt
    """
    }

    ch_indices_only
        .splitCsv(sep: ',', skip: 1)
        .map { name, main_file -> [name, file(main_file) ] }
        .set { ch_indices }

    process stage_index_files {
    tag "id:${name}"
    publishDir "results/staged_files_checksums/indices_only/"

    input:
    set val(name), file(file_path) from ch_indices

    output:
    file("${name}_indices_only_md5sum.txt") into ch_indices_only_lists

    script:
    """
    md5sum *${params.index_suffix} > ${name}_indices_only_md5sum.txt
    """
    }

    ch_complete_file_sets
        .splitCsv(sep: ',', skip: 1)
        .map { name, main_file, index_file -> [ name, file(main_file), file(index_file) ] }
        .set { ch_complete_sets }

    process stage_file_sets {
    tag "id:${name}"
    publishDir "results/staged_files_checksums/completed_file_sets/"

    input:
    set val(name), file(file_path), file(file_index) from ch_complete_sets

    output:
    file("${name}_completed_file_sets_md5sum.txt") into ch_completed_file_sets_list

    script:
    """
    md5sum *${params.file_suffix}* > ${name}_completed_file_sets_md5sum.txt
    """
    }

    ch_main_files_lists
        .concat(ch_indices_only_lists)
        .concat(ch_completed_file_sets_list)
        .set { ch_checksums }

    process collect_checksums {
    tag "id:${name}"
    publishDir "results/staged_files_checksums/"

    input:
    file(checksums) from ch_checksums.collect()

    output:
    file("all_checksums.txt")

    script:
    """
    cat *txt > all_checksums.txt
    """
    }
}
