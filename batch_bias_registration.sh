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
sAtlas='atlas_'
mat='.mat'


for folder in $srcDir/*
do
  echo 

	pid=${folder#"$srcDir/"}  #get patient id
	if [ ! -d "$outDir/$pid" ]; then
		mkdir -p $outDir/$pid
	fi

  #######get the available modality in this folder
  modality="" #empty modality

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
      # modality+=("${cur_mod[@]}")
      # if [[ ! " $modality " =~ " $cur_mod " ]]; then
      if [[ ! " $modality " =~ " $cur_mod " ]]; then
        modality+="$cur_mod "
      fi
  done


  info="...Phase 1: bias correction #$number: $pid"
  echo $info
	for sMod in ${modality[@]}
	do
      pidPath=$folder/$sRaw$pid$sMod$suffix
      n4Path=$folder/$n4$pid$sMod$suffix
      echo '-------: '$pidPath
      echo '+++++++: '$n4Path
      printf '\n'
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Preprocessing -n4 -i $pidPath -o $n4Path
	done
	

  #####assign local reference image
  # echo -e "ref: $ref, modality: $modality"
  if [[ ${modality[@]} == *_t1ce* ]]; then #if t1ce exist
      ref='_t1ce'
  elif [[ ${modality[@]} == *_t1* ]]; then #if t1 exists
      ref='_t1'
  else
      ref=${modality[0]} #take the first element as reference
  fi
  ref="${ref// /}" #remove space if it exists

  info="...Phase 2: register to t1ce  #$number: $pid"
  echo $info
  sReg='reg_'
	for sMod in ${modality[@]}
	do
      n4Path=$folder/$n4$pid$sMod$suffix
      refPath=$folder/$n4$pid$ref$suffix
      aff1=$folder/$n4$pid$sMod$mat
      regPath=$folder/$sReg$pid$sMod$suffix
      # echo -e "\n n4Path: $n4Path, refPath: $refPath, regPath=$regPath"
      #generate affine transformation matric
      /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Preprocessing  -i $n4Path -rFI $refPath -o $regPath -reg affine -rIA $aff1 -rME NCC-2x2x2 -rIS 1 -rNI 100,50,5
      # /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Preprocessing  -i $n4Path -rFI $refPath -o $regPath -reg Rigid -rIA $aff1 -rME NMI -rIS 1 -rNI 100,50,5
	done
	
	
  atlasPath='atlas_reference.nii.gz'

  info="...Phase 3: n4 image register to atlas  #$number: $pid"
  echo $info
  sReg2='atlas_'
  refPath=$folder/$n4$pid$ref$suffix
  aff2=$folder/$pid$ref$mat
  regPath2=$folder/$sReg2$pid$suffix
  # echo "ref: $ref, refPath: $refPath, atlasPath: $atlasPath, regPath2: $regPath2"
  /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Preprocessing  -i $refPath -rFI $atlasPath -o $regPath2 -reg affine -rIA $aff2 -rME NCC-2x2x2 -rIS 1 -rNI 100,50,5
  # /Applications/CaPTk_1.8.1.app/Contents/Resources/bin/./Preprocessing  -i $refPath -rFI $atlasPath -o $regPath2 -reg Rigid -rIA $aff2 -rME NMI -rIS 1 -rNI 100,50,5

  info="...Phase 4: all register to atlas  #$number: $pid"
  mat_files=$(find "$folder" -type f -name "*.mat") #find all matric files
  atlas_mat=$(echo $mat_files|grep -oE '\S*atlas\S*') #extract the matric file obtained from the atlas registration
  update_mat_files=${mat_files//$atlas_mat/} #update the matric files by removing the atlas matric
	 
  attempt=""
  # echo "modality: $modality"
	for sMod in ${modality[@]}
	do
    if [[ ! " $attempt " =~ " $sMod " ]]; then
      reg2Path=$folder/$sReg2$pid$suffix
      # pidPath=$folder/$sRaw$pid$sMod$suffix
      # aff1=$(echo "$update_mat_files"|grep "$sMod") #extract the matric file obtained from the atlas registration
      # echo "sMod: $sMod, aff1: $aff1"
      aff1=$folder/$n4$pid$sMod$mat
      aff2=$folder/$pid$ref$mat
      tarPath=$outDir/$pid/$pid$sMod$suffix
      atlasPath=$outDir/$pid/$sAtlas$pid$sMod$suffix
      cp $reg2Path $tarPath
      cp $reg2Path $atlasPath
    fi
	done

 #  info="...Phase 5: clean data  #$number: $pid"
 #  echo $info
	# for sMod in ${modality[@]}
	# do
 #      n4Path=$folder/$n4$pid$sMod$suffix
 #      aff1=$folder/$n4$pid$sMod$mat
	# done
	#
 #  aff2=$folder/$pid$ref$mat

  printf "\n"

  ((number++))
done
end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."
