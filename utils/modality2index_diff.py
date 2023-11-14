def modality2index_diff(s_modality, all_modality='f1c2'):
    assert len(all_modality) >= len(s_modality)
    all_dic = {'f': 0, '1': 1, 'c': 2, '2': 3}
    all_index = [all_dic[x] for x in all_modality]
    has_index = [all_dic[x] for x in s_modality]
    diff_index = list(set(all_index) - set(has_index))
    return diff_index
