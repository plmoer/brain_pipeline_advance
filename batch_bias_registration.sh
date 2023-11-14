#The script is to batch bias + co-registration using CBICA CaPTK (version: 1.8.0) and greedy
#Author: Linmin Pei
#Date: Oct. 05, 2020
#Prerequistie: CBICA CaPTK 1.8.0 and greedy

#!/bin/bash
start_time=`date +%s`
# srcDir='/home/lin/Desktop/new_GBM' #source directory
# outDir='/home/lin/Desktop/new_GBM_atlas' #output directory
regType=$1
srcDir=$2
outDir=$3
# atlasPath='atlas_reference.nii.gz'
# interPath='inter_reference.nii.gz'
suffix='.nii.gz' #format extension

#modality=("_t1" "_t1ce" "_t2" "_flair")
number=1
n4='n4_'
sRaw='raw_'
# t1ce='_t1ce'
mat='.mat'



for folder in $srcDir/*
do
	pid=${folder#"$srcDir/"}  #get patient id
	if [ ! -d $outDir/$pid ]; then
		mkdir -p $outDir/$pid
	fi

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
      fi
      modality+=("${cur_mod[@]}")
  done

  info="...Phase 1: bias correction #$number: $pid"
  echo $info
	for sMod in ${modality[@]}
	do
      pidPath=$folder/$sRaw$pid$sMod$suffix
      n4Path=$folder/$n4$pid$sMod$suffix
      # echo '-------: '$pidPath
      # echo '+++++++: '$n4Path
      # printf '\n'
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Preprocessing -n4 -i $pidPath -o $n4Path
	done


  #####assign local reference image
  if [[ ${modality[@]} == *_t1ce* ]]; then #if t1ce exist
      ref='_t1ce'
  elif [[ ${modality[@]} == *_t1* ]]; then #if t1 exists
      ref='_t1'
  else
      ref=${modality[0]} #take the first element as t1ce
  fi

  info="...Phase 2: register to t1ce  #$number: $pid"
  echo $info
  sReg='reg_'
	for sMod in ${modality[@]}
	do
      n4Path=$folder/$n4$pid$sMod$suffix
      refPath=$folder/$n4$pid$ref$suffix
      aff1=$folder/$n4$pid$sMod$mat
      regPath=$folder/$sReg$pid$sMod$suffix
      #generate affine transformation matric
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -a -m NMI -i $refPath $n4Path -o $aff1 -ia-image-centers -n 100x50x10 -dof 6
      if [[ $regType == "intra" ]]; then
        #register the n4 image to the reference image
        /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -rf $refPath -ri LINEAR -rm $n4Path $regPath -r $aff1
      fi
	done

  atlasPath='atlas_reference.nii.gz'

  info="...Phase 3: n4_t1ce register to atlas  #$number: $pid"
  echo $info
  refPath=$folder/$n4$pid$ref$suffix
  aff2=$folder/$pid$ref$mat
  /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -a -m NMI -i $atlasPath $refPath -o $aff2 -ia-image-centers -n 100x50x10 -dof 6

  info="...Phase 4: all register to atlas  #$number: $pid"
  echo $info
	for sMod in ${modality[@]}
	do
      pidPath=$folder/$sRaw$pid$sMod$suffix
      aff1=$folder/$n4$pid$sMod$mat
      aff2=$folder/$pid$ref$mat
      tarPath=$outDir/$pid/$pid$sMod$suffix
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./greedy -d 3 -rf $atlasPath -ri LINEAR -rm $pidPath $tarPath -r $aff2 $aff1
	done

  info="...Phase 5: clean data  #$number: $pid"
  echo $info
	for sMod in ${modality[@]}
	do
      n4Path=$folder/$n4$pid$sMod$suffix
      aff1=$folder/$n4$pid$sMod$mat
      # rm $n4Path
      rm $aff1
	done

  aff2=$folder/$pid$ref$mat
  rm $aff2

  printf "\n"

  ((number++))
done
end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."
