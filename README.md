# lifebit-ai/designfile

Minimal Nextflow workflow that collects the paths from an S3 location (bucket, folder of bucket) into a design file to be used for subsequent workflows


## Usage

Typical usage:

```bash
nextflow run main.nf --s3_location  's3://lifebit-featured-datasets/IGV/' --file_suffix 'cram' --index_suffix 'crai'
```

### Parameters

#### `--s3_location`

The S3 location of the bucket or a folder of the bucket. For example `'s3://lifebit-featured-datasets/IGV/'`.

#### `--file_suffix`

The file suffix, for example`'cram'`.

#### `--index_suffix`

The file index suffix, for example `'crai'`.

#### `--output_file`

The name of the output file to write the design file with the columns:
- name
- file
- index

For example `design.csv`. It must have a ".csv" siffix, or else the pipeline will stop with an error similar to the following:

```console
You have specified the --output_file to be 'this.txt', which does not indicate a comma sepearated file.
Please specify an output file name with --output_file that ends with .csv
```
#### `--stage_data`

_Optional_

This flag can be used to test the staging of the data, not recommended if the outcome is only to retrieve the design files that points to the locations.
However, the process can be used as an example of how would the file be read into a channel for use in the subsequent workflow that ustilises the data described in the design file.

The process can be used as a template for the first process that needs to access the data listed in `design.csv`.
If you are starting in a new Nextflow pipeline using the output file from [`lifebit-ai/designfile`](https://github.com/lifebit-ai/designfile) you can make use of the following snippet:

```groovy
// Define ideally in nextflow.config instead of main.nf and initialise to false
params.design_file = "results/design.csv"

// Re-usable component to create a channel with the links of the files by reading the design file that has a header (skip:1 ommits this 1st row)
Channel.fromPath(params.design_file)
    .splitCsv(sep: ',', skip: 1)
    .map { name, file_path, index_path -> [ name, file(file_path), file(index_path) ] }
    // .set { ch_files_sets }
    .view()

// Re-usable process skeleton that performs a simple operation, listing files
process view_file_sets {
tag "id:${name}-file:${file_path}-index:${index_path}"
echo true
publishDir "results/${name}/", mode: "copy"

input:
set val(name), file(file_path), file(index_path) from ch_files_sets

output:
file("${name}.txt")

script:
"""
ls -lL > ${name}.txt
"""
}

```

## Output

The output file is expected to look like this:

```csv
# contents of design.csv file

name,file,index
SARS-COV2_pass,s3://lifebit-featured-datasets/IGV/cram/SARS-COV2_pass.minimap2.sorted.cram,s3://lifebit-featured-datasets/IGV/cram/SARS-COV2_pass.minimap2.sorted.cram.crai
HG002_ONT,s3://lifebit-featured-datasets/IGV/samplot/HG002_ONT.cram,s3://lifebit-featured-datasets/IGV/samplot/HG002_ONT.cram.crai
```
