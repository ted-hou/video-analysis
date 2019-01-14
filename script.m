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

close all
for iTr = 1:length(tr)
	try
		plotBodyPart(vtd, tr, iTr, 2, 'SmoothingWindow', [1 1], 'SmoothingMethod', 'movmean', 'Window', [0, 2], 'TLim', [-7, 2], 'NumSigmas', 2);
	catch ME
		warning(['Error when processing file ', num2str(iTr), '!'])
		warning(sprintf('Error in program %s.\nTraceback (most recent at top):\n%s\nError Message:\n%s', mfilename, getcallstack(ME), ME.message))
	end				
end
clear iTr



% New OO
va = VideoAnalysis.BatchLoad();
va.ProcessEvents('Reference', 'CueOn', 'Event', 'PressOn');
va.ProcessData('FrontRightPaw', 'Window', [0, 2], 'SmoothingMethod', 'movmean', 'SmoothingWindow', [1, 1], 'NumSigmas', 2, 'NumSigmasSpeed', 2);

va.Plot('FrontRightPaw');
va.Hist('FrontRightPaw');