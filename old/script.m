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
va.ProcessData({'FrontLeftPaw', 'FrontRightPaw'}, 'Window', [0, 2], 'SmoothingMethod', 'movmean', 'SmoothingWindow', [1, 1], 'NumSigmas', 2, 'NumSigmasSpeed', 2);

va.Plot('FrontRightPaw');
va.Hist('FrontRightPaw');

% Get vid clip
for iVa = 1:length(va)
	cliptimes = cellfun(@(data) data(2).Speed.MoveTimeAbs, {va(iVa).Trials.BodyPart});
	cliptimes = cliptimes(1:10);
	clip{iVa} = va(iVa).GetVideoClip(cliptimes, 'TrackingDataType', 'Smooth', 'BodyPart', {'FrontRightPaw', 'FrontLeftPaw'});
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

% Ah
va = VideoAnalysis.BatchLoad();
va.ProcessEvents('Reference', 'CueOn', 'Event', 'PressOn');
va.ProcessData({'FrontLeftPaw', 'FrontRightPaw'}, 'Window', [0, 2], 'SmoothingMethod', 'movmean', 'SmoothingWindow', [1, 1], 'NumSigmas', 2, 'NumSigmasSpeed', 2);

PETH = va.PETHistcounts(batchPlotList, false);
PETHCorrected = va.PETHistcounts(batchPlotList, true);

close all
[~, ~, I] = TetrodeRecording.HeatMap(PETH, 'Normalization', 'zscore', 'Sorting', 'latency', 'MinNumTrials', 75, 'MinSpikeRate', 15, 'Window', [-4, 0], 'NormalizationBaselineWindow', [-4, 0]);
TetrodeRecording.HeatMap(PETHCorrected, 'Normalization', 'zscore', 'Sorting', 'latency', 'MinNumTrials', 75, 'MinSpikeRate', 15, 'Window', [-4, 0], 'NormalizationBaselineWindow', [-4, 0], 'I', I);

ax = findobj('Type', 'Axes');
delete(ax([1, 3]))
ax = ax([4 2]);

title(ax(1), 'Aligned to lever-touch')
title(ax(2), 'Aligned to move onset')

xlabel(ax(1), 'Time relative to lever-touch (s)')
xlabel(ax(2), 'Time relative to move onset (s)')

ax(1).Position = [0.2, 0.2, 0.6, 0.6];
ax(2).Position = [0.2, 0.2, 0.6, 0.6];




va.Hist('NonPositive', true, 'TLim', [-4, 0]);


