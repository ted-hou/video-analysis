%% 
croptrimGetParams()
croptrimSaveParams()
save('C:\Server\params.mat', 'Params')

% in anaconda terminal:
cd C:\GIT\video-analysis
python croptrimExec.py

%%
datetime.setDefaultFormats('default','yyyy-MM-dd hh:mm:ss.SSSS Z')

cd('C:\SERVER\VideoTracking')
vtd = getVideoTrackingData();
[tr, vtd] = loadTetrodeRecording(vtd);

for iVtd = 1:length(vtd)
	vtd(iVtd).NumMissingFrames = length(vtd(iVtd).Time) - length(vtd(iVtd).BodyPart(1).X);
end
clear iVtd


for iTr = 1:length(tr)
	plotBodyPart(vtd, tr, iTr, 2, 'SmoothingWindow', [2 2], 'SmoothingMethod', 'movmean', 'Window', [0, 2]);
end