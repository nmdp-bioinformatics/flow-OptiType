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
      --with-docker nmdpbioinformatics/flow-OptiType \
      --bamdir /location/of/bamfiles --outfile typing_results.txt

*/

optiref=file("/usr/local/bin/OptiType/data/hla_reference_dna.fasta")
outfile = file("${params.outfile}")
bamglob = "${params.bamdir}/*.bam"
bamfiles = Channel.fromPath(bamglob).ifEmpty { error "cannot find any reads matching ${bamglob}" }.map { path -> tuple(sample(path), path) }

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
  tag{ subid }

  input:
    set subid, file(fq1), file(fq2) from fastqFiltered
  output:
    stdout optioutput

  """
  OptiTypePipeline.py -i ${fq1} ${fq1} --id ${subid} --dna --outdir na
  """
}

optioutput
.collectFile() {  typing ->
       [ "typing_results.txt", typing ]
   }
.subscribe { file -> copy(file) }

def copy (file) { 
  log.info "Copying ${file.name} into: $outfile"
  file.copyTo(outfile)
}

def sample(Path path) {
  def name = path.getFileName().toString()
  int start = Math.max(0, name.lastIndexOf('/'))
  return name.substring(start, name.indexOf("."))
}
