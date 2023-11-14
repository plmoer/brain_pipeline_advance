'''
The function is to check the modality in the pid_path folder
input: pid_path
output: symbol of available modality, such as, 'f1c2'. f->flair, 1->t1/pre, c->t1ce/post, and 2->t2
Author: Linmin
Revised date: Jan. 08, 2021
'''
import os
def checkModality(pid_path):
    s_modality=''
    if os.path.exists(pid_path) == False:
        raise ValueError('The path does not exist!')
    modList = os.listdir(pid_path)
    all_modality=''.join(modList) #convert to a long string

    #the sequence is very imporant!
    if '_flair.nii.gz' in all_modality:
        s_modality+='f'
    if '_t1.nii.gz' in all_modality:
        s_modality+='1'
    if '_t1ce.nii.gz' in all_modality:
        s_modality+='c'
    if '_t2.nii.gz' in all_modality:
        s_modality+='2'

    return s_modality
