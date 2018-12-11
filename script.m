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

%%
% for iTr = 1:length(tr)
for iTr = 1:16
	posX = [vtd(iTr).BodyPart(2).X];
	posY = [vtd(iTr).BodyPart(2).Y];

	pos = [0; sqrt(diff(posX).^2 + diff(posY).^2)];

	prob = [vtd(iTr).BodyPart(2).Likelihood];

	samplingFreq = (length(vtd(iTr).Time) - 1)/seconds(vtd(iTr).Time(end) - vtd(iTr).Time(1));
	t = milliseconds(vtd(iTr).Time - vtd(iTr).Time(1));
	cutOffFreq = 0.001;

	figure(iTr)
	hold on
	plot(t, lowpass(pos, cutOffFreq, samplingFreq), 'r')
	plot(milliseconds(tr(iTr).GetStartTime() + seconds(tr(iTr).DigitalEvents.PressOn) - vtd(iTr).Time(1)), 250, 'ro')
	hold off
	title(['LP - ', num2str(cutOffFreq), ' Hz'])
end
