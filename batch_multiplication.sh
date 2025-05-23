#The script is to batch zscore normalization using CBICA CaPTK (version: 1.8.0)
#Author: Linmin Pei
#Date: Nov. 11, 2023
#Prerequistie: FSL (fslmaths)

#!/bin/bash
start_time=`date +%s`
outDir=$1
suffix='.nii.gz' #format extension

# modality=("_t1" "_t1ce" "_t2" "_flair")
number=1
mask='_mask'




for folder in $outDir/*
do
	pid=${folder#"$outDir/"}  #get patient id
	if [ ! -d $outDir/$pid ]; then
		mkdir -p $outDir/$pid
	fi

    info="...Phase 1: image multiplication #$number: $pid"
    echo $info

    for modPath in $folder/*
    do 
      maskPath=$folder/$pid$mask$suffix
      if [[ $modPath != $maskPath && "$modPath" != *atlas_* ]]; then
         fslmaths $modPath -mul $maskPath $modPath
      fi

    done
    printf "\n"

    ((number++))
done
end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."

