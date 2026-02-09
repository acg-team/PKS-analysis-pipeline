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

The pipeline is designed to run with **Nextflow** using a custom **Conda/Mamba** environment defined in `environment.yml`.

### Cluster Setup

#### UZH HPC
Install and configure the environment using Nix and Micromamba:
```bash
nix-env --install micromamba
nix-env --install nextflow
micromamba shell init --shell=bash --prefix=~/micromamba
micromamba create -f environment.yml
```

### Local Setup

#### Standard Workstation (e.g., Linux/Intel Mac)
```bash
micromamba config --set channel_priority disabled
micromamba create -f environment.yml
```

## Software Versions

The environment includes the following software versions:
*   **Nextflow**
*   **Python 3.12**
*   **PRANK**: v.170427
*   **MAFFT**: v7.526
*   **RAxML-ng**: v2.0-beta3 (supports automatic model selection)
*   **BEAST 2**

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
*   **Purpose**: Aligning sequences with a focus on evolutionary events.
*   **Settings**: `prank -d=${fasta} -o=${fasta.baseName}.prank -F`
    *   `-F`: Trusts the inference of insertions; sites appearing as insertions are not re-aligned in later stages.

#### MAFFT
*   **Purpose**: Fast and accurate alignment.
*   **Settings**: `mafft --auto ${fasta} > ${fasta.baseName}.mafft.aln`
    *   `--auto`: Automatically selects the appropriate strategy based on data size.

### 3. ML phylogenetics (RAxML-NG)

RAxML-NG (v2.0-beta3) is used for its support of **Automatic Model Selection (MOOSE)** and **Adaptive Tree Search**.

#### Model Selection
The pipeline leverages MOOSE to select the best-fitting evolutionary model. Below is the list of models evaluated, selected based on their applicability to the dataset (bacterial PKS):

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

#### Topology Optimization
Tree search is guided by the **Pythia score**, a machine-learning predictor of dataset difficulty (likelihood surface ruggedness).
*   **Easy datasets**: Single likelihood peak; search converges rapidly and terminates early.
*   **Difficult datasets**: Many local optima; search finds one good topology quickly to save time.
*   **Intermediate datasets**: Requires more extensive search.
