#!/bin/bash

# ----------------------------------------------------------------------------
# Copyright (c) 2015--, The WGS-HGT Development Team.
#
# Distributed under the terms of the Modified BSD License.
#
# The full license is in the file COPYING.txt, distributed with this software.
# ----------------------------------------------------------------------------

# usage: run HGTector software
database_fp=$1
diamond_nr=$2
diamond_tabular_query=$3
hgtector_config_file=$4
hgtector_install_dir=$5
query_species_coding_seqs_fp=$6
working_dir=$7
threads=$8
taxid=$9
taxdump_dp=${10}
gi_to_taxid_fp=${11}

mkdir -p "${working_dir}/diamond"

if [ "${gi_to_taxid_fp}" == "None" ]
then
    echo "GI to TaxID translation file is required."
    exit
fi

## Align with DIAMOND if alignments don't exist
if [ "${diamond_tabular_query}" == "None" ]
then
    ## Build database if doesn't exist
    if [ "${diamond_nr}" == "None" ]
    then
        diamond_nr=${working_dir}/diamond/$(basename ${database_fp%.*})
        diamond makedb --in ${database_fp} -d ${diamond_nr} --threads $threads
    fi
    ## Run DIAMOND
    filename=$(basename "${query_species_coding_seqs_fp}")
    diamond_output=${working_dir}/diamond/$filename
    diamond blastp --db ${diamond_nr} \
                   --query ${query_species_coding_seqs_fp} \
                   --evalue 1e-5 \
                   --max-target-seqs 500 \
                   --threads ${threads} \
                   --daa ${diamond_output}.daa \
                   --sensitive
    # convert output to tab delimited format
    diamond view --daa ${diamond_output}.daa -f tab -o ${diamond_output}.m8
    diamond_tabular_query=${diamond_output}.m8
fi

## Run HGTector
mkdir -p ${working_dir}/hgtector
mkdir -p ${working_dir}/hgtector/input
cp $query_species_coding_seqs_fp ${working_dir}/hgtector/input

## create config.txt (if wasn't passed)
if [ "${hgtector_config_file}" == "None" ]
then
    hgtector_config_file=${working_dir}/hgtector/config.txt
    touch $hgtector_config_file
    echo -e "title=trial_001\n\
    interactive=0\n\
    searchTool=DIAMOND\n\
    protdb=${diamond_nr}.dmnd\n\
    taxdump=${taxdump_dp}\n\
    prot2taxid=$gi2taxid.tsv\n\
    preSearch=${diamond_tabular_query}\n\
    evalue=1e-20\n\
    identity=30\n\
    coverage=50\n\
    minSize=30\n\
    ignoreSubspecies=1\n\
    graphFp=1\n\
    exOutlier=2\n" > "$config_fp"
    if [ "${tax_id}" != "None" ]
    then
        echo "selfTax=id:$taxid" >> "$config_fp"
    fi
fi

perl ${hgtector_install_dir}/HGTector.pl ${working_dir}/hgtector
## print a list of predicted HGT-derived genes
echo ${working_dir}/hgtector/result/HGT/id.txt
