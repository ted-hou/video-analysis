# -*- coding: utf-8 -*-
"""
Load params generated in MATLAB and execute video processing.
	1) Crop to ROI
	2) Trim so both videos start and end at the same time (or as close as possible)
	3) Convert to grey image by setting saturation=0
"""
from scipy.io import loadmat
import os, subprocess

params = loadmat('C:\Server\params.mat')
params = params['Params']
for iDir in range(params.size):
    for iVid in range(params[0, iDir]['Video'].size):
        file 		= params[0, iDir]['Video'][0, iVid]['File'][0];
        crop 		= params[0, iDir]['Video'][0, iVid]['Crop'][0];
        frameNumber = params[0, iDir]['Video'][0, iVid]['FrameNumber'][0];
        timestamp 	= params[0, iDir]['Video'][0, iVid]['Timestamp'][0];
        command = 'ffmpeg -y -i "' + file + '.mp4"' + ' -vf "eq=saturation=0, crop=' + str(crop[2]) + ':' + str(crop[3]) + ':' + str(crop[0]) + ':' + str(crop[1]) + ', trim=start_frame=' + str(frameNumber[0]) + ':end_frame=' + str(frameNumber[-1] + 1) + '" "' + file + '_cropped.mp4"'
        print(command)
        subprocess.call(command, shell=True)