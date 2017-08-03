#!/usr/bin/env nextflow
/*

    nextflow script for running optitype on BAM files
    Copyright (c) 2014-2015 National Marrow Donor Program (NMDP)

    This library is free software; you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License as published
    by the Free Software Foundation; either version 3 of the License, or (at
    your option) any later version.

    This library is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; with out even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
    License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this library;  if not, write to the Free Software Foundation,
    Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA.

    > http://www.gnu.org/licenses/lgpl.html

  ./nextflow run nmdp-bioinformatics/flow-Optitype \
    --with-docker nmdpbioinformatics/flow-optitype \
    --outfile hli-optitype.csv \
    --bamdir s3://bucket/s3/data \
    --datatype dna
*/

params.help = ''
params.datatype = 'dna'

optiref=file("/usr/local/bin/OptiType/data/hla_reference_dna.fasta")
outfile = file("${params.outfile}")
bamglob = "${params.bamdir}/*.bam"
datatype = "${params.datatype}"
bamfiles = Channel.fromPath(bamglob).ifEmpty { error "cannot find any reads matching ${bamglob}" }.map { path -> tuple(sample(path), path) }

/*  Help section (option --help in input)  */
if (params.help) {
    log.info ''
    log.info '---------------------------------------------------------------'
    log.info 'NEXTFLOW OPTITYPE'
    log.info '---------------------------------------------------------------'
    log.info ''
    log.info 'Usage: '
    log.info 'nextflow run main.nf -with-docker nmdpbioinformatics/flow-optitype --bamdir bamfiles/ [--datatype rna] [--outfile datafile.txt]'
    log.info ''
    log.info 'Mandatory arguments:'
    log.info '    --bamdir      FOLDER             Folder containing BAM FILES'
    log.info 'Options:'
    log.info '    --datatype    STRING             Type of sequence data (default : dna)'
    log.info '    --outfile     STRING             Name of output file (default : typing_results.txt)'
    log.info ''
    exit 1
}

/* Software information */
log.info ''
log.info '---------------------------------------------------------------'
log.info 'NEXTFLOW OPTITYPE'
log.info '---------------------------------------------------------------'
log.info "Input BAM folder   (--bamdir)    : ${params.bamdir}"
log.info "Sequence data type (--datatype)  : ${params.datatype}"
log.info "Output file name   (--outfile)   : ${params.outfile}"
log.info "Project                          : $workflow.projectDir"
log.info "Git info                         : $workflow.repository - $workflow.revision [$workflow.commitId]"
log.info "\n"

// Extract pair reads to fq files
process bam2fastq {
  errorStrategy 'ignore'
  tag{ subid }
  
  input:
    set subid, file(bamfile) from bamfiles
  output:
    set subid, file("${subid}.end1.fq") into fastq1
    set subid, file("${subid}.end2.fq") into fastq2

  """
  bedtools bamtofastq -i ${bamfile} -fq ${subid}.end1.fq -fq2 ${subid}.end2.fq 
  """
}

//Filter the fq files
process razarEnd1 {
  errorStrategy 'ignore'
  tag{ subid }
  
  input:
    set subid, file(fq) from fastq1
  output:
    set subid, file("${subid}.raz-end1.fastq") into razarFilteredEnd1

  """
  razers3 --percent-identity 90 --max-hits 1 --distance-range 0 --output ${subid}.raz-end1.sam ${optiref} ${subid}.end1.fq
  cat ${subid}.raz-end1.sam | grep -v ^@ | awk '{print "@"\$1"\\n"\$10"\\n+\\n"\$11}' > ${subid}.raz-end1.fastq
  """
}

//Filter the fq files
process razarEnd2 {
  errorStrategy 'ignore'
  tag{ subid }
  
  input:
    set subid, file(fq) from fastq2
  output:
    set subid, file("${subid}.raz-end2.fastq") into razarFilteredEnd2

  """
  razers3 --percent-identity 90 --max-hits 1 --distance-range 0 --output ${subid}.raz-end2.sam ${optiref} ${subid}.end2.fq
  cat ${subid}.raz-end2.sam | grep -v ^@ | awk '{print "@"\$1"\\n"\$10"\\n+\\n"\$11}' > ${subid}.raz-end2.fastq
  """
}

//Collect filtered fq files
fqPairs = Channel.create()
fastqFiltered = razarFilteredEnd1.phase(razarFilteredEnd2).map{ fq1, fq2 -> [ fq1[0], fq1[1], fq2[1] ] }.tap(fqPairs)

//Run OptiType
process optitype {
  errorStrategy 'ignore'
  tag{ subid }

  input:
    set subid, file(fq1), file(fq2) from fastqFiltered
  output:
    stdout optioutput

  """
  OptiTypePipeline.py -i ${fq1} ${fq1} --id ${subid} --${datatype} --outdir na
  """
}

// Print out results to output file
optioutput
.collectFile() {  typing ->
       [ "typing_results.txt", typing ]
   }
.subscribe { file -> copy(file) }

// On completion
workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Duration    : ${workflow.duration}"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

def copy (file) { 
  log.info "Copying ${file.name} into: $outfile"
  file.copyTo(outfile)
}

def sample(Path path) {
  def name = path.getFileName().toString()
  int start = Math.max(0, name.lastIndexOf('/'))
  return name.substring(start, name.indexOf("."))
}
