# -*- coding: utf-8 -*-
"""
Load params generated in MATLAB and execute video cropping and trimming.
"""

from scipy.io import loadmat
params = loadmat('/media/lingfeng/Data/Folder/params.mat')
params = params['Params']
for iDir in range(params.size):
    for iVid in range(params[iDir]['Video'].size):
        framenumber = params[iDir]['Video'][iVid]['FrameNumber'];
        timestamp = params[iDir]['Video'][iVid]['Timestamp'];
        crop = params[iDir]['Video'][iVid]['Crop'];
        crop = params[iDir]['Video'][iVid]['File'];