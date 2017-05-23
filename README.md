# flow-OptiType
Run BAM files through OptiType in parallele with nextflow and docker. 

For more information on OptiType please refer to the oficial [repository](https://github.com/FRED-2/OptiType).

### Setup
```bash
sudo apt-get update
sudo apt-get install -y docker docker-engine git
curl -fsSL get.nextflow.io | bash
```

### Usage
```bash
./nextflow run nmdp-bioinformatics/flow-Optitype \
    --with-docker nmdpbioinformatics/flow-OptiType \
    --bamdir /location/of/bamfiles --outfile typing_results.txt
```

### Reference
Szolek, A, Schubert, B, Mohr, C, Sturm, M, Feldhahn, M, and Kohlbacher, O (2014). OptiType: precision HLA typing from next-generation sequencing data Bioinformatics, 30(23):3310-6.
