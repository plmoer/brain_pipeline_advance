#The script is to batch skull stripping using CBICA CaPTK (version: 1.8.0)
#Author: Linmin Pei
#Date: Oct. 05, 2020
#Prerequistie: CBICA CaPTK 1.8.0 and skull stripping model

#!/bin/bash
start_time=`date +%s`
# srcDir='/home/lin/Desktop/RRC-GBM-PRE_atlas' #source directory
srcDir=$1
#outDir='/home/lin/Desktop/upmc_data_brain' #output directory
modelDir='/opt/CaPTk/1.8.0/saved_models/skullStripping'

modality=("_t1" "_t1ce" "_t2" "_flair")
number=1
t1ce='_t1ce'
t1='_t1'
t2='_t2'
fl='_flair'
mask='_mask'
suffix='.nii.gz' #format extension
comma=','
for folder in $srcDir/*
do
	pid=${folder#"$srcDir/"}  #get patient id
    echo $pid
#	if [ ! -d $outDir/$pid ]; then
#		mkdir -p $outDir/$pid
#	fi

    info="...Phase 1: brain extraction #$number: $pid"
    echo $info
    t1_img=$folder/$pid$t1$suffix
    t1ce_img=$folder/$pid$t1ce$suffix
    t2_img=$folder/$pid$t2$suffix
    fl_img=$folder/$pid$fl$suffix
    maskDir=$folder/$pid$mask
    /opt/CaPTk/1.8.0/CaPTk-1.8.0.bin DeepMedic.cwl -md $modelDir -i $t1_img,$t1ce_img,$t2_img,$fl_img -o $maskDir
    postPath='predictions/testApiSession/predictions/Segm.nii.gz'

    maskPath=$folder/$pid$mask/$postPath #full mask path
    tarPath=$folder/$pid$mask$suffix
    cp $maskPath $tarPath
    rm -rf $maskDir



    printf "\n"

    ((number++))
done
end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."

