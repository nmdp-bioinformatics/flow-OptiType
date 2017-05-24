# flow-OptiType
Run BAM files through OptiType in parallel with nextflow and docker.  For more information on OptiType please refer to the official [repository](https://github.com/FRED-2/OptiType).

## Deploy AWS Cluster

```bash
# nextflow.config
cloud {
    imageId = 'ami-dabffecc'
    instanceType = 'm4.xlarge'
    userName = 'your_username'
    keyName = 'your_keyname'
    autoscale {
        enabled = true
        minInstances = 2
        maxInstances = 10
        terminateWhenIdle = true
    }
}

# installation and cluster setup
curl -fsSL get.nextflow.io | bash
./nextflow cloud create optitype-cluster -c 3
ssh -i ~/.ssh/your_keyname your_username@ip.returned.above.step
```
I recommend using the **ami-dabffecc** image because it was specifically built for running this process. You can change or remove the autoscale properties depending on the resources you require. For more information on this configuration please refer to the [nextflow documentation](https://www.nextflow.io/docs/latest/awscloud.html).

### Usage
```bash
./nextflow run nmdp-bioinformatics/flow-Optitype \
    -with-docker nmdpbioinformatics/flow-optitype \
    --bamdir s3://location/of/bamfiles --outfile typing_results.txt
```
Running this will pull down this repository and run the main.nf nextflow script. It will also pull down the docker image associated with this repository. If you have the [aws cli](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) set up you can point the script to an S3 bucket that contains your BAM files.


### OptiType Reference
Szolek, A, Schubert, B, Mohr, C, Sturm, M, Feldhahn, M, and Kohlbacher, O (2014). OptiType: precision HLA typing from next-generation sequencing data Bioinformatics, 30(23):3310-6.

### Nextflow Reference
Di Tommaso, P., Chatzou, M., Floden, E. W., Barja, P. P., Palumbo, E., & Notredame, C. (2017). Nextflow enables reproducible computational workflows. Nat Biotech, 35(4), 316–319. 