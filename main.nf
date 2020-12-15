// Re-usable componext for adding a helpful help message in our Nextflow script
def helpMessage() {
    log.info"""
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run main.nf --s3_location  's3://lifebit-featured-datasets/IGV/' --file_suffix 'cram' --index_suffix 'crai'
    Mandatory arguments:

    """.stripIndent()
}


Channel.fromPath("${params.s3_location}/**/*.{${params.file_suffix},${params.index_suffix}}")
       .map { it -> [ file(it).simpleName, "s3:/"+it] }
       .groupTuple(by:0)
    //    .view()
       .set { ch_files }

    process create_design_row {
    tag "${name}"
    echo true

    input:
    set val(name), val(s3_file) from ch_files
    echo true

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
    echo true

    output:  
    file 'design.csv' 

    """
    echo "name,file,index" > header.csv
    for row in $design_rows; do cat \$row >> body.csv; done
    cat header.csv body.csv > design.csv
    """
    }