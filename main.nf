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

Channel.fromPath("${params.s3_location}/**/*.{${params.file_suffix},${params.index_suffix}}")
       .map { it -> [ file(it).simpleName, "s3:/"+it] }
       .groupTuple(by:0)
       .set { ch_files }

    process create_design_row {
    tag "file:${name}"

    input:
    set val(name), val(s3_file) from ch_files

    output:
    file "${name}.csv" into ch_rows
    """
    echo "${name},${s3_file.collect {"$it"}.join(',')}" > ${name}.csv
    cat ${name}.csv
    """
    }

    process bind_design_rows {
    publishDir 'results/', mode: 'copy'

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

    echo "name,index"      > only_indices_${params.output_file}
    echo "name,file"       > only_main_files_${params.output_file} 
    echo "name,file,index" > complete_file_sets_${params.output_file}

    grep -v '.${params.file_suffix},' body.csv | grep -v '.${params.file_suffix}\$'  >> only_indices_${params.output_file}
    grep '.${params.file_suffix}\$'   body.csv >> only_main_files_${params.output_file}
    grep    '.${params.file_suffix},' body.csv >> complete_file_sets_${params.output_file}
    """
    }

if (params.stage_files) {

    // Re-usable component to create a channel with the links of the files by reading the design file that has a header (skip:1 ommits this 1st row)
    ch_main_files_only
        .splitCsv(sep: ',', skip: 1)
        .map { name, main_file -> [name, file(main_file) ] }
        .set { ch_main_files }

    // Re-usable process skeleton that performs a simple operation, listing files
    process stage_main_files {
    tag "id:${name}"
    echo true
    publishDir "results/main_files_only/"

    input:
    set val(name), file(file_path) from ch_main_files

    output:
    file("${name}.txt")

    script:
    """
    ls -lL > ${name}.txt
    ls -lL
    """
    }

    // Re-usable component to create a channel with the links of the files by reading the design file that has a header (skip:1 ommits this 1st row)
    ch_indices_only
        .splitCsv(sep: ',', skip: 1)
        .map { name, main_file -> [name, file(main_file) ] }
        .set { ch_indices }

    // Re-usable process skeleton that performs a simple operation, listing files
    process stage_index_files {
    tag "id:${name}"
    echo true
    publishDir "results/indices_only/"

    input:
    set val(name), file(file_path) from ch_indices

    output:
    file("${name}.txt")

    script:
    """
    ls -lL > ${name}.txt
    ls -lL
    """
    }

    // Re-usable component to create a channel with the links of the files by reading the design file that has a header (skip:1 ommits this 1st row)
    ch_complete_file_sets
        .splitCsv(sep: ',', skip: 1)
        .map { name, main_file, index_file -> [name, file(main_file), file(index_file) ] }
        .set { ch_complete_sets }

    // Re-usable process skeleton that performs a simple operation, listing files
    process stage_file_sets {
    tag "id:${name}"
    echo true
    publishDir "results/${name}/"

    input:
    set val(name), file(file_path), file(file_index) from ch_complete_sets

    output:
    file("${name}.txt")

    script:
    """
    ls -lL > ${name}.txt
    ls -lL
    """
    }
}
