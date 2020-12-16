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
    publishDir 'results/'

    input:
    file(design_rows) from ch_rows.collect()

    output:  
    file("${params.output_file}") into ch_design_file
    set file("only_indices_missing_main_file.csv"), file("files_with_missing_indices.csv")
    
    """
    echo "name,file,index" > header.csv
    for row in $design_rows; do cat \$row >> body.csv; done
    cat header.csv body.csv > ${params.output_file}
    grep -v '".${params.file_suffix}$"'  ${params.output_file}  > only_indices_missing_main_file.csv
    grep -v '".${params.index_suffix}$"'  ${params.output_file} > files_with_missing_indices.csv
    """
    }

if (params.stage_files) {

    // Re-usable component to create a channel with the links of the files by reading the design file that has a header (skip:1 ommits this 1st row)
    ch_design_file
        .splitCsv(sep: ',', skip: 1)
        .map { name, file_path, index_path -> [ name, file(file_path), file(index_path) ] }
        .set { ch_files_sets }

    // Re-usable process skeleton that performs a simple operation, listing files
    process view_file_sets {
    tag "id:${name}-file:${file_path}-index:${index_path}"
    echo true
    publishDir "results/${name}/"

    input:
    set val(name), file(file_path), file(index_path) from ch_files_sets

    output:
    file("${name}.txt")

    script:
    """
    ls -lL > ${name}.txt
    """
    }
}
