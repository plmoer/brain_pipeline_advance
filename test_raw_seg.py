"""
Author: Linmin Pei
Date: Nov. 24th, 2020
Difference between test_raw.py and test_online.py is the data saved form.
In test_online.py, all image modalities are fused into one nifti file.
However, in test_raw.py, all image modalities are saved as a seperated files (even in raw image status)
"""

import os
import random
import sys
import time

import numpy as np
import SimpleITK as sitk
import torch
import torch.optim as optim
from torch.autograd import Variable

from utils import mask_conversion
from utils.checkModality import checkModality
from utils.imagePadding import *
from utils.loadFusionImage import loadFusionImage
from utils.modality2index_diff import modality2index_diff
from utils.post_processing import post_processing
from utils.unet_ensemble import UNet

# import ipdb
# ipdb.set_trace(context=20)


# regType = str(sys.argv[1])
imageDir = str(sys.argv[1])

temp_modalName = "ckpt_seg_big_"
# if regType == 'atlas':
#     temp_modalName = 'ckpt_seg_big_'
# else:
#     temp_modalName = 'ckpt_seg_small_'

previous_modality = ""

macString = ".DS_Store"
all_dic = {
    "f": "_flair.nii.gz",
    "1": "_t1.nii.gz",
    "c": "_t1ce.nii.gz",
    "2": "_t2.nii.gz",
}
bNorm = True  # True: need to be normalized, otherwise False
bPostProcess = True
bTradition = False
# if regType != 'atlas':
#     bTradition = True
bTTA = False
# bTTA = True


num_ndf = 16  # base channel
num_batch = 1  # number of batch size
# num_channel = 4  # number of channel: flair, t1, t1ce, and t2
num_class = 3  # number of class
seed = 1024  # seed
model_path = "models"  # seed
cwd = os.getcwd()
modelDir = os.path.join(cwd, model_path)  # path to save models

# bGPU = False
bGPU = torch.cuda.is_available()  # check gpu
maskConversionObj = getattr(mask_conversion, "de_conversion")


def loadModel(sModelName, num_channel=4, num_class=1, num_ndf=16):
    model = UNet(num_channel, num_class, num_ndf)
    # model = torch.nn.DataParallel(model)
    if bGPU == True:
        ckpt = torch.load(os.path.join(modelDir, sModelName), weights_only=True)
    else:
        ckpt = torch.load(
            os.path.join(modelDir, sModelName),
            map_location=lambda storage, loc: storage,
            weights_only=True,
        )
    model.load_state_dict(ckpt["model_state_dict"])

    if bGPU == True:  # gpu use
        model = model.cuda()
    return model


def initial(seed):  # initialization
    torch.manual_seed(int(seed))
    torch.cuda.manual_seed(int(seed))
    random.seed(int(seed))
    np.random.seed(int(seed))


def execution(patList):
    global previous_modality
    for idx, pid in enumerate(patList):
        print("...working on {}: {}/{}".format(pid, idx + 1, len(patList)))
        pid_path = os.path.join(imageDir, pid)  # get image full path
        s_modality = checkModality(pid_path)
        num_channel = len(s_modality)  # channel number
        print("---pid {} has modality: {}\n".format(pid, s_modality))
        # if current modality is different from the previous on
        if s_modality != previous_modality:
            sModelName = temp_modalName + s_modality
            model = loadModel(sModelName, num_channel, num_class, num_ndf)
            model.eval()  # change to testing mode

        modality = [all_dic[x] for x in s_modality]
        dataInfo, data = loadFusionImage(pid_path, pid, modality, bNorm)
        origin = dataInfo["origin"]
        spacing = dataInfo["spacing"]
        direction = dataInfo["direction"]

        # data shape: 4x155x240x240data = imgPadding(data)
        [nSlice, nRow, nCol] = data.shape[1:]
        data = imgPadding(data, 32)  # image padding

        # after normalization, pix value in background is around -3
        data = data[None, ...]  # 1x4x160x240x240
        data = torch.from_numpy(data)

        data = data.type(torch.FloatTensor)
        data = Variable(data)  # gpu version
        if bGPU == True:
            data = data.cuda()
        with torch.no_grad():
            output = model(data)

            if bTTA == True:
                output += model(data.flip(dims=(2,))).flip(dims=(2,))
                output += model(data.flip(dims=(3,))).flip(dims=(3,))
                output += model(data.flip(dims=(4,))).flip(dims=(4,))
                output += model(data.flip(dims=(2, 3))).flip(dims=(2, 3))
                output += model(data.flip(dims=(2, 4))).flip(dims=(2, 4))
                output += model(data.flip(dims=(3, 4))).flip(dims=(3, 4))
                output += model(data.flip(dims=(2, 3, 4))).flip(dims=(2, 3, 4))
                output = output / 8.0
            prediction = output[0]  # batchsize = 1
            if bGPU == True:
                prediction_arr = prediction.data.cpu().numpy()
            else:
                prediction_arr = prediction.data.numpy()
            prediction_arr = (prediction_arr > 0.5).astype(int)
            mask = maskConversionObj(prediction_arr, bTradition)
            # mask = mask[:155]  # crop to 155x240x240 because of padding

        if bPostProcess == True:
            mask = post_processing(mask)

        # de-padding if there is padding before
        mask = deImgPadding(mask, nRow, nCol, nSlice)

        savedName = pid + "_seg.nii.gz"
        segDir = os.path.join(pid_path, savedName)

        mask_obj = sitk.GetImageFromArray(mask)
        mask_obj.SetOrigin(origin)
        mask_obj.SetSpacing(spacing)
        mask_obj.SetDirection(direction)

        sitk.WriteImage(mask_obj, segDir)


def main():
    patList = os.listdir(imageDir)
    if macString in patList:
        patList.remove(macString)
    patList.sort()
    initial(seed)
    execution(patList)


if __name__ == "__main__":
    startTime = time.time()
    main()
    endTime = time.time()
    print("It takes %d seconds to complete!" % (endTime - startTime))
