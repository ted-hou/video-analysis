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

%%
for iTr = 1:length(tr)
	pos = [vtd(iTr).BodyPart(2).X];
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