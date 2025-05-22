#The bash script is to segment brain tumor which includes several steps:
#1. Dicom to nifti conversion
#2. Change orientation
#3. Coregister to an atlas
#4. Skull stripping
#5. Brain extraction by multiply skull stripping mask to all images
#6. Brain tumor segmentation
#7. Reverse registration

#Prerequistie: CBICA CaPTK 1.8.0 (or later version) and FSL(https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation)

#atlas: the registration result has the space as atlas
#intra: the registration result has the space as the T1ce, or T1 (if t1ce is missing) in the same patient
#raw: the registration result has the space as atlas
#
#Author: Linmin Pei
#Date: Nov. 12, 2023

#!/bin/bash
start_time=`date +%s`
regType="raw" #registration type: atlas, intra, or raw 
srcDir='/Users/peil2/Desktop/brain/raw_image' #source directory of raw dicom images
tmpDir='/Users/peil2/Desktop/brain/tmp_image' #temporary directory saving intermediate results
outDir='/Users/peil2/Desktop/brain/output' #output directory to store registered images, masks, and segmentations


echo '------------Dicom to Nifti--------------------'
bash ./batch_dcm2nifti.sh $srcDir $tmpDir

echo '------------Coregistration-------------------'
bash ./batch_bias_registration.sh $regType $tmpDir $outDir

echo '------------Skull Stripping------------------'
python3 test_raw_mask.py $outDir


echo '------------Brain extraction-----------------'
bash ./batch_multiplication.sh $outDir


echo '------------Brain tumor segmentation---------'
python3 test_raw_seg.py $outDir


echo '------------Reverse registration ---------------'
bash ./batch_reverse.sh $regType $tmpDir $outDir

end_time=`date +%s`
echo ".....It takes `expr $end_time - $start_time` s to finish the task....."
