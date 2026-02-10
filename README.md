# PKS-analysis-pipeline

This repository contains a Nextflow pipeline for polyketide synthase (PKS) phylogenetic analysis. The pipeline performs sequence alignment using `mafft` and `prank` and estimates phylogenetic trees using `RAxML-NG` (ML tree with automatic evolutionary model selection) and `Beast2` (Bayesian inference).

## Pipeline Overview

1.  **Preprocessing**: Cleans FASTA headers (removing specific formatting artifacts).
2.  **Alignment**: Sequences are aligned in parallel using:
    *   **PRANK** (probabilistic alignment)
    *   **MAFFT** (heuristic alignment)
3.  **Phylogenetics**:
    *   **RAxML-NG**: Maximum likelihood tree inference with automatic model selection and adaptive tree search.
    *   **BEAST2**: Bayesian phylogenetic inference (XML configuration generated automatically).

## Environment Setup

The pipeline is designed to run with [**Nextflow**](https://www.nextflow.io/) using a custom **Conda/Mamba** environment.

### Software Versions

The analysis environment includes the following key software versions defined in `environment.yml`:

*   **Python 3.12**
*   [**PRANK**](https://ariloytynoja.github.io/prank-msa/) v.170427
*   [**MAFFT**](https://mafft.cbrc.jp/alignment/server/index.html) v7.526
*   [**RAxML-NG**](https://github.com/amkozlov/raxml-ng) v2.0-beta3 (supports automatic model selection)
*   [**BEAST2**](https://www.beast2.org/) v2.6.3

### Cluster Setup

#### UZH Wagner HPC

Install and configure the environment using Nix and Micromamba:

```bash
nix-env --install micromamba
nix-env --install nextflow
git clone https://github.com/acg-team/PKS-analysis-pipeline.git
cd PKS-analysis-pipeline
micromamba shell init --shell=bash --prefix=~/micromamba
micromamba create -f setup_env/environment.yml
```

#### ZHAW HPC

Install and configure the environment using a setup bach script:

```bash
git clone https://github.com/acg-team/PKS-analysis-pipeline.git
cd PKS-analysis-pipeline/setup_env
./init_env_zhaw_cluster.sh
cd ..
```

### Local Setup

#### Standard Workstation (e.g., Linux/Intel Mac)

**Prerequisites**: `micromamba` and `nextflow`  installed.

```bash
git clone https://github.com/acg-team/PKS-analysis-pipeline.git
cd PKS-analysis-pipeline
micromamba create -f setup_env/environment.yml
```

## Running The Analysis

**Prerequisites**:
1. `micromamba` and `nextflow`  installed, pre-configured `micromamba` environment created but not activated.
2. Data for the analysis placed in the `data/` folder in the repository root folder.

### Running on UZH Wagner HPC

**Prerequisites**: replace the path to the environment in `nextflow_uzh_cluster.config` with the appropriate environment path, e.g.:

`conda = '/home/jpecerska/micromamba/envs/polyketide_analysis'`

To run the pipeline using the Slurm workload manager, run the following command:

`nextflow run pipeline.nf -c nextflow_uzh_cluster.config`

### Running locally

**Prerequisites**: replace the path to the environment in `nextflow_local.config` with the appropriate environment path, e.g.:

`conda = '/Users/pece/mamba/envs/polyketide_analysis`

To run the pipeline using the local machine, run the following command:

`nextflow run pipeline.nf -c nextflow_local.config`

## Analysis Steps Detailed

### 1. Data Cleaning

The pipeline performs automatic cleaning of input FASTA files:
*   **Symbol Removal**: Removes `['` and `']` characters from sequences. These are formatting artifacts that can cause PRANK to replace residues with unknown amino acids (`X`).
*   **Header Sanitization**: Ensure headers do not contain parentheses (which break RAxML).
    *   *Example fix manually applied to `PKS_AT_prot_seq.fasta`:*
        *   Old: `>NZ_SZVR01000041_M6_bis_N/A_mxmal/(unknown)/mxmal`
        *   New: `>NZ_SZVR01000041_M6_bis_N/A_mxmal/unknown/mxmal`

### 2. Alignment

#### PRANK

**Command**:

`prank -d=${fasta} -o=${fasta.baseName}.prank -F`

**Settings**:
*   `-F`: Trusts the inference of insertions; sites appearing as insertions are not re-aligned in later stages.

#### MAFFT

**Command**:

`mafft --auto ${fasta} > ${fasta.baseName}.mafft.aln`

**Settings**:
*   `--auto`: Automatically selects the appropriate strategy based on data size.

### 3. ML phylogenetics (RAxML-NG)

RAxML-NG (v2.0-beta3) is used for its support of **Automatic Model Selection (MOOSE)** and **Adaptive Tree Search**.

**Command (DNA sequences)**:

`raxml-ng-2 --msa ${alignment} --model DNA --opt-topology adaptive --prefix ${alignment.baseName}`

**Command (protein sequences)**:

`raxml-ng-2 --msa ${alignment} --model AA --moose-options substitution-models=DCMut,JTT,JTT-DCMut,LG,PMB,Q.pfam,Q.yeast,VT,WAG,PROTGTR --opt-topology adaptive --prefix ${alignment.baseName}`

**Settings**:
*   `--model`: Sets the input sequence type `DNA` for DNA sequences or `AA` for protein sequences.
*   `--moose-options`: Defines the substitution models to use in model selection (only for protein sequences, described in section [Model Selection](#model-selection)).
*   `--opt-topology adaptive`: Activates adaptive tree search based on Pythia difficulty scores (described in section [Topology Optimisation](#topology-optimisation)).

#### Model Selection
The pipeline uses MOOSE to select the best-fitting evolutionary model. For DNA sequences it will go through all available substitution models (e.g. JC69, K80, GTR), for proteins it will evaluate a list of models in the table below, selected based on their applicability to the dataset (bacterial PKS):

| Model Name    | Reference                   | Included? | Comment                                       |
| :------------ | :-------------------------- | :-------- | :-------------------------------------------- |
| **DCMut**     | Kosiol and Goldman, 2005    | **Yes**   | Improved version of PAM model                 |
| **JTT**       | Jones et al., 1992          | **Yes**   | Generic model                                 |
| **JTT-DCMut** | Kosiol and Goldman, 2005    | **Yes**   | Corrected Dayhoff rate matrices               |
| **LG**        | Le and Gascuel, 2008        | **Yes**   | Generic model                                 |
| **PMB**       | Veerassamy et al., 2003     | **Yes**   | Updated BLOSUM62 model                        |
| **Q.pfam**    | Minh et al., 2021           | **Yes**   | Generic model derived from PFAM               |
| **VT**        | Muller and Vingron, 2000    | **Yes**   | Extension of Dayhoff approach                 |
| **WAG**       | Whelan and Goldman, 2001    | **Yes**   | Generic model                                 |
| **PROTGTR**   | -                           | **Yes**   | General Time Reversible (190 rate parameters) |
| Blosum62      | Henikoff and Henikoff, 1992 | No        | Omitted in favor of PMB                       |
| Dayhoff       | Dayhoff et al., 1978        | No        | Omitted in favor of JTT-DCMut                 |
| Q.yeast       | Minh et al., 2021           | No*       | Yeast model (not applicable to bacteria)      |

*(Note: Many specific organismal models like HIV, Flu, Mammal, Bird, Plant, Insect, and Mitochondrial models were excluded as they are not applicable to this analysis.)*

#### Topology Optimisation
Tree search is guided by the **Pythia score**, a machine-learning predictor of dataset difficulty (likelihood surface ruggedness).
*   **Easy datasets**: Single likelihood peak; search converges rapidly and terminates early.
*   **Difficult datasets**: Many local optima; search finds one good topology quickly to save time.
*   **Intermediate datasets**: Requires more extensive search.

### 4. Bayesian Phylogenetics (Beast2)

The pipeline automates the generation of Beast2 XML configuration files and execution.

*   **XML Generation**: A Python script (`scripts/beast_configuration.py`) automatically generates the XML configuration file for each alignment.
    *   It uses a template (`beast_template/protein_template.xml` for protein sequences or `beast_template/dna_template.xml` for DNA) to ensure consistent parameters.
    *   It parses the FASTA alignment, sanitizes sequence IDs (replacing non-alphanumeric characters), and inserts the sequences into the XML structure.
*   **Beast2 run**: Beast2 is run on the generated XML files to perform Bayesian phylogenetic inference.

**Execution**:

`beast -threads ${task.cpus} -overwrite ${xml}`

**Settings**:
*   `-threads`: Enables parallelisation based on available CPU count.
*   `-overwrite`: Allows overwriting of files to prevent getting stuck on user input.

#### Beast2 Analysis Configuration

The pipeline uses two specific templates for Bayesian phylogenetic inference, depending on the input data type. No model selection is available, so the substitution models are fixed.

Template settings:

*   **MCMC Chain Length**: 10,000,000 generations.
*   **Logging Frequency**: Every 1,000 generations (for trees, trace logs, and screen output).
*   **Tree Prior**: [Birth-Death Model](https://www.sciencedirect.com/science/article/abs/pii/S0022519308001811?via%3Dihub).
*   **Clock Model**: Strict Clock with a fixed rate of 1.0.
*   **Site Model**: Gamma Site Model with 5 categories and invariant sites (G+I).
*   **Specific Configurations**:
    * **Protein Alignments** (using `protein_template.xml`):
        * Substitution Model: [WAG](https://academic.oup.com/mbe/article/18/5/691/1018653).
    * **DNA Alignments** (using dna_template.xml):
        * Substitution Model: GTR (General Time Reversible) with estimated base frequencies and rate parameters.
