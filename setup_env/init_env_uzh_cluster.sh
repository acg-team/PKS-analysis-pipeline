#!/usr/bin/env bash

# ## strict bash mode
set -eEuo pipefail

export CFS_HOME=${HOME}
export PATH=${HOME}/bin:${PATH}

# ## install micromamba
if [[ ! -f ${CFS_HOME:?}/bin/micromamba ]]; then
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
    mkdir -p ${CFS_HOME:?}/bin
    mv bin/micromamba ${CFS_HOME:?}/bin
    rmdir bin
fi
# ## init micromamba
export MAMBA_ROOT_PREFIX="${CFS_HOME:?}/.conda/"
eval "$("${CFS_HOME:?}/bin/micromamba" shell hook -s posix)"

environment_file=environment.yml
env_name=$(sed -ne 's/^name: \(.*\)$/\1/p' ${environment_file:?})
echo "load (and set up) environment ${env_name:?}"

# ## install env if it does not exist
if ! micromamba env list | grep -Eq "^\s*${env_name:?} "; then
    echo "create conda environment ${env_name:?}"
    micromamba -y create -f ${environment_file:?} || { echo "environment creation failed!"; exit 1; }
fi

# ## install java via nix if not already available
if [[ ! -f ${CFS_HOME:?}/.nix-profile/bin/java ]]; then
    echo "installing java via nix"
    nix-env --install openjdk
fi

# ## install nextflow
if [[ ! -f ${CFS_HOME:?}/bin/nextflow ]]; then
    curl -s https://get.nextflow.io | bash
    chmod +x nextflow
    mkdir -p ${CFS_HOME:?}/bin
    mv nextflow ${CFS_HOME:?}/bin
else
    nextflow self-update
fi
echo "setup done"
