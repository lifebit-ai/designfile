<p align="center">
  <img src="https://avatars0.githubusercontent.com/u/30871219?s=200&v=4"  width="50" align="right" >
</p>

#  `lifebit-ai/designfile` 
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

The file suffix, default: `'cram'` (:warning: note: without the leading dot '.')

#### `--index_suffix`

The file index suffix, default: `'crai'` (:warning: note: without the leading dot '.')

#### `--output_file`

The name of the output file to write the design file with the columns:
- name
- file
- index

Default: `design.csv`. It must have a ".csv" suffix, or else the pipeline will stop with an error similar to the following:

```console
You have specified the --output_file to be 'this.txt', which does not indicate a comma sepearated file.
Please specify an output file name with --output_file that ends with .csv
```

Four output files will be generated.

Given the `--output_file` is **`design.csv`** the expected file names are:

#####  1. **`design.csv`:**

Comma seperated file with 3 columns, `name, file, index`.
Contains as many rows as unique names of files matching the `--file_suffix`, `--index_suffix` regex in the defined `--s3_location`.
In the case that the set of files (main, index) is missing either the main file (eg. `cram`) or the index file (eg. `crai`), some rows will have less than 3 entries.

#####  2. `only_indices_`**`design.csv`:**

Comma seperated file with 2 columns, `name, index`.
Contains as many rows as the numder of file sets that are missing the main file and only have the index file.
All rows are expected to have 2 columns.

#####  3. `only_main_files_`**`design.csv`:**

Comma seperated file with 2 columns, `name, index`.
Contains as many rows as the numder of file sets that are missing the index in file and only have the index file.
All rows are expected to have 2 columns.

##### 4. `complete_file_sets_`**`design.csv`:**

Comma seperated file with 3 columns, `name, file, index`.
Contains as many rows as the numder of file sets that are missing the main file and only have the index file.
All rows are expected to have 3 columns.

#### `--stage_files`

_Optional_ (Default: `false`)

This flag can be used to test the staging of the data, not recommended if the outcome is only to retrieve the design files that points to the locations.
However, the process can be used 1) to retrieve the md5sums of the files 2) serve as an Nextflow snippet example of how would the design.csv file can be read into a channel for use in the subsequent workflow.

If `--stage_files` is set to `true`, files with the md5sum will be generated per process for each file set or single main/index files and a collective one that summarises all the files found in the `--s3_location`.

A typical results folder structure will be the following:

```console
results
└── s3_locations/
    ├── complete_file_sets_design.csv
    ├── design.csv
    ├── only_indices_design.csv
    └── only_main_files_design.csv
└── staged_files_checksums/
    └── main_files_only/..
    └── indices_only/..
    └── completed_file_sets/..
    └── all_checksums.txt
```


The process can be used as a template for the first process that needs to access the data listed in `design.csv`.
If you are starting in a new Nextflow pipeline using the output file from [`lifebit-ai/designfile`](https://github.com/lifebit-ai/designfile), you can make use of 

<details>
<summary> the following Nextflow snippet:</summary>

```groovy
// contents of main.nf

// Define ideally in nextflow.config instead of main.nf and initialise to false
params.design_file = "results/complete_file_sets_design.csv"

// Re-usable component to create a channel with the links of the files by reading the design file that has a header (skip:1 ommits this 1st row)
Channel.fromPath(params.design_file_complete_sets)
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
  ls -l > ${name}.txt
  ls -l
  """
  }
```

</details>


## Output

The output file is expected to look like this:

### `design.csv`

```csv
# contents of design.csv file

name,file,index
SARS-COV2_pass,s3://lifebit-featured-datasets/IGV/cram/SARS-COV2_pass.minimap2.sorted.cram,s3://lifebit-featured-datasets/IGV/cram/SARS-COV2_pass.minimap2.sorted.cram.crai
HG002_ONT,s3://lifebit-featured-datasets/IGV/samplot/HG002_ONT.cram,s3://lifebit-featured-datasets/IGV/samplot/HG002_ONT.cram.crai
```

### `all_checksums.txt`

_(generated only when `--stage_files = true` only_)

```console
➜ cat results/staged_files_checksums/all_checksums.txt
0850d3291bbdd5e5d90cbd9c5a3c62c0  HG002_ONT.cram
3ac542da496c30958b6bce343733f743  HG002_ONT.cram.crai
29c8c0566961706964b7342168f7ca7d  SARS-COV2_pass.minimap2.sorted.cram
6392bc8e30400d1a018cb47b59790078  SARS-COV2_pass.minimap2.sorted.cram.crai
```