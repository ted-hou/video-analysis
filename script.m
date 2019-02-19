%% 1. Crop/trim videos
croptrimGetParams()
croptrimSaveParams()
save('C:\Server\params.mat', 'Params')

% in anaconda terminal:
cd C:\GIT\video-analysis
python croptrimExec.py

%% 2. Run DLC on cropped videos


%% 3. [OBSOLETE] Analyze DLC generated teacking data (loose scripts)
% datetime.setDefaultFormats('default','yyyy-MM-dd hh:mm:ss.SSSS Z')

% cd('C:\SERVER\VideoTracking')
% vtd = getVideoTrackingData();
% [tr, vtd] = loadTetrodeRecording(vtd);

% for iVtd = 1:length(vtd)
% 	vtd(iVtd).NumMissingFrames = length(vtd(iVtd).Time) - length(vtd(iVtd).BodyPart(1).X);
% end
% clear iVtd

% close all
% for iTr = 1:length(tr)
% 	try
% 		plotBodyPart(vtd, tr, iTr, 2, 'SmoothingWindow', [1 1], 'SmoothingMethod', 'movmean', 'Window', [0, 2], 'TLim', [-7, 2], 'NumSigmas', 2);
% 	catch ME
% 		warning(['Error when processing file ', num2str(iTr), '!'])
% 		warning(sprintf('Error in program %s.\nTraceback (most recent at top):\n%s\nError Message:\n%s', mfilename, getcallstack(ME), ME.message))
% 	end				
% end
% clear iTr



%% 3. Analyze DLC generated teacking data (New OO method)
va = VideoAnalysis.BatchLoad();
va.ProcessEvents('Reference', 'CueOn', 'Event', 'PressOn');
va.ProcessData('FrontRightPaw', 'Window', [0, 2], 'SmoothingMethod', 'movmean', 'SmoothingWindow', [1, 1], 'NumSigmas', 2, 'NumSigmasSpeed', 2);

va.Plot('FrontRightPaw');
va.Hist('FrontRightPaw');

% Get vid clip
for iVa = 1:length(va)
	clip{iVa} = va(iVa).GetVideoClip(cellfun(@(data) data(2).Speed.MoveTimeAbs, {va(iVa).Trials.BodyPart}), 'TrackingDataType', 'Smooth', 'BodyPart', 'FrontRightPaw');
end
clip = vertcat(clip{:});

% View video clip
iClip = 1;
while iClip <= length(clip)
	f = figure('Units', 'normalized', 'Position', [0 0 0.3 0.3]);
	ax = axes(f);
	title(ax, [num2str(iClip), ' / ', num2str(length(clip))]);
	implay(clip{iClip})
	iskb = waitforbuttonpress;
	if iskb
		iClip = max(1, iClip - 1);
	else
		iClip = iClip + 1;
	end
	close all force
end