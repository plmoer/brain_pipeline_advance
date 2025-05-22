#The script is to batch bias + co-registration using CBICA CaPTK (version: 1.8.0) and greedy
#Author: Linmin Pei
#Date: Nov. 13, 2023
#Prerequistie: CBICA CaPTK 1.8.0 and greedy

#!/bin/bash
start_time=`date +%s`
regType=$1
tempDir=$2
outDir=$3
# atlasPath='atlas_reference.nii.gz'
# interPath='inter_reference.nii.gz'
suffix='.nii.gz' #format extension
prefix='' #format extension

number=1
n4='n4_'
sReg='reg_'
sAff='aff_'
mat='.mat'
sSeg='_seg'
sOut='_seg'
sMask='_mask'


if [[ $regType = "atlas" ]]; then
  echo " ******************* Complete! *******************"
elif [[ $regType = "raw" ]]  ||  [[ $regType = "intra" ]]; then
  for folder in $outDir/*
  do
    pid=${folder#"$outDir/"}  #get patient id
    if [ ! -d $outDir/$pid ]; then
      mkdir -p $outDir/$pid
    fi
    echo 

    #######get the available modality in this folder
    modality=() #empty modality
    for entry in "$folder"/* #for each modality having full path
    do
        temp_mod=${entry#"$folder/"} 
        if [[ $temp_mod == *"_t1.nii.gz"* ]]; then
            cur_mod="_t1"
        elif [[ $temp_mod == *"_t1ce.nii.gz"* ]]; then
            cur_mod="_t1ce"
        elif [[ $temp_mod == *"_t2.nii.gz"* ]]; then
            cur_mod="_t2"
        elif [[ $temp_mod == *"_flair.nii.gz"* ]]; then
            cur_mod="_flair"
        else
            cur_mod=""
        fi

        if [[ ! " $modality " =~ " $cur_mod " ]]; then
          modality+=("$cur_mod")
        fi
    done

    if [[ ${modality[@]} == *_t1ce* ]]; then #if t1ce exist
        ref='_t1ce'
    elif [[ ${modality[@]} == *_t1* ]]; then #if t1 exists
        ref='_t1'
    else
        ref=${modality[0]} #take the first element as t1ce
    fi
    ref="${ref// /}" #remove space if it exists

    info="...Phase 6: reverse images  #$number: $pid"
    echo $info
    for sMod in ${modality[@]}
    do
        inPath=$folder/$pid$sMod$suffix
        if [ $regType = "raw" ]; then
          n4Path=$tempDir/$pid/$n4$pid$sMod$suffix
        else
          n4Path=$tempDir/$pid/$sReg$pid$sMod$suffix
        fi
        # n4Path=$folder/$n4$pid$sMod$suffix
        aff3=$tempDir/$pid/$sAff$pid$sMod$mat
        revPath=$folder/$prefix$pid$sMod$suffix
        echo "inPath: $inPath, n4Path: $n4Path, aff3: $aff3, revPath: $revPath"

        /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -a -m NMI -i $n4Path $inPath -o $aff3 -ia-image-centers -n 100x50x10 -dof 6
        /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -rf $n4Path -ri LINEAR -rm $inPath $revPath -r $aff3
    done
    printf '\n'

    info="...Phase 7: reverse segmentations  #$number: $pid"
    echo $info
    segPath=$folder/$pid$sSeg$suffix
    outPath=$folder/$pid$sOut$suffix
    if [ $regType = "raw" ]; then
      n4Path=$tempDir/$pid/$n4$pid$ref$suffix
    else
      n4Path=$tempDir/$pid/$sReg$pid$ref$suffix
    fi
    aff3=$tempDir/$pid/$sAff$pid$ref$mat
    /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -rf $n4Path -ri NN -rm $segPath $outPath -r $aff3

      info="...Phase 8, reverse brain mask #$number: $pid"
      echo $info
      old_maskPath=$folder/$pid$sMask$suffix
      n4Path=$tempDir/$pid/$sReg$pid$sMod$suffix
      aff4=$tempDir/$pid/$sReg$pid$sMod$mat
      new_maskPath=$folder/$pid$sMask$suffix
      echo "aff4: $aff4"
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -a -m NMI -i $n4Path $old_maskPath -o $aff4 -ia-image-centers -n 100x50x10 -dof 6
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -rf $n4Path -ri NN -rm $old_maskPath $new_maskPath -r $aff4

    ((number++))
  done


else 
  echo "=============== Error ==============: "$regType" Only accept 'atlas', 'raw', and 'intra'!"
fi

# rm -rf $tempDir

end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."
