#The script is to batch dicom to nifti using CBICA CaPTK (version: 1.8.0)
#Author: Linmin Pei
#Date: Nov. 02, 2020
#Prerequistie: CBICA CaPTK 1.8.0 and dcm2nifti model

#!/bin/bash
start_time=`date +%s`
# srcDir='/home/lin/Downloads/New-GBM' #source directory
# outDir='/home/lin/Desktop/new_GBM2' #output directory
srcDir="$1"
outDir="$2"

echo $srcDir
echo $outDir

#prefix='RRC-'
prefix=''
#modality=("_t1" "_t1ce" "_t2" "_flair")
sRaw='raw_'
suffix='.nii.gz' #format extension
orientation='RAS' #RAS or LPS
number=1
for folder in $srcDir/*
do
	pid=${folder#"$srcDir/"}  #get patient id
    pid=$prefix$pid
#	if [ ! -d $outDir/$pid ]; then
#		mkdir -p $outDir/$pid
#	fi

    info="...Phase 1: dicom ---> nifti #$number: $pid"
    echo $info

    for subfolder in $folder/*; do #access each modality
        for dcmfile in $subfolder/*; do
            # echo '------------'$dcmfile
            # echo '++++++++++++'$folder
            # /opt/CaPTk/1.8.0/CaPTk-1.8.0.bin Utilities.cwl -d2n -i $dcmfile -o $folder #convert dcm to nifti
            /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Utilities -d2n -i $dcmfile -o $folder #convert dcm to nifti
            break 1
        done
    done

    printf "\n"

    ((number++))
done

new_number=1
for folder in $srcDir/*
do
	pid=${folder#"$srcDir/"}  #get patient id
    pid=$prefix$pid
	if [ ! -d $outDir/$pid ]; then
		mkdir -p $outDir/$pid
	fi

    info="...Phase 2: change orientation #$new_number: $pid"
    echo $info


    for sourceFile in $folder/*.nii.gz; do #access each modality
        if [[ $sourceFile == *$pid"_t1ce_"*".nii.gz" ]]; then
            modality='_t1ce.nii.gz'
            echo $modality
        elif [[ $sourceFile == *$pid"_t1_"*".nii.gz" ]]; then
            modality='_t1.nii.gz'
            echo $modality
        elif [[ $sourceFile == *$pid"_t2_"*".nii.gz" ]]; then
            modality='_t2.nii.gz'
            echo $modality
        elif [[ $sourceFile == *$pid"_flair_"*".nii.gz" ]]; then
            modality='_flair.nii.gz'
            echo $modality
        # if [[ $sourceFile == *$pid"-PRET1_"*".nii.gz" ]]; then
        #     modality='_t1.nii.gz'
        #     echo $modality
        # elif [[ $sourceFile == *$pid"-T1POST_"*".nii.gz" ]]; then
        #     modality='_t1ce.nii.gz'
        #     echo $modality
        # elif [[ $sourceFile == *$pid"-T2_"*".nii.gz" ]]; then
        #     modality='_t2.nii.gz'
        #     echo $modality
        # elif [[ $sourceFile == *$pid"-T2FLR_"*".nii.gz" ]]; then
        #     modality='_flair.nii.gz'
            # echo $modality
        fi
        dst_nifti=$outDir/$pid/$sRaw$pid$modality
        /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Utilities -or $orientation -i $sourceFile -o $dst_nifti #orientation change
        jasonFile=$sourceFile
        jasonFile=${jasonFile/.nii.gz/.json}
        rm $sourceFile #delete the temprary file .nii.gz
        rm $jasonFile #delete the temprrary file .json
    done
    printf "\n"

    ((new_number++))
done
end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."

