%% 
croptrimGetParams()
croptrimSaveParams()
save('C:\Server\params2.mat', 'Params')

% in anaconda terminal:
cd C:\GIT\video-analysis
python croptrimExec.py

%%

datetime.setDefaultFormats('default','yyyy-MM-dd hh:mm:ss.SSSS Z')

cd('D:\DeepLabCut\videos')
vtd = getVideoTrackingData();
[tr, vtd] = loadTetrodeRecording(vtd);

for iTr = 1:length(tr)
	disp(['NEV Time - ', datestr(tr(iTr).GetStartTime())]);
	disp(['MP4 Time - ', datestr(vtd(iTr).Time(1))]);
end


%%
iTr = 1;
pos = [vtd(iTr).BodyPart(2).X];
samplingFreq = (length(vtd(iTr).Time) - 1)/seconds(vtd(iTr).Time(end) - vtd(iTr).Time(1));
t = milliseconds(vtd(iTr).Time - vtd(iTr).Time(1));
cutOffFrequecies = 10.^[-1:-1:-10];
for iCutOffFrequecy = 1:length(cutOffFrequecies)
	figure(iCutOffFrequecy)
	hold on
	% plot(t, pos, 'k')
	plot(t, lowpass(pos, cutOffFrequecies(iCutOffFrequecy), samplingFreq), 'r')
	plot(milliseconds(tr(iTr).StartTime + seconds(tr(iTr).DigitalEvents.PressOn) - vtd(iTr).Time(1)), 250, 'ro')
	hold off
	title(['LP - ', num2str(cutOffFrequecies(iCutOffFrequecy)), ' Hz'])
end

speed = sqrt([0; diff(vtd(iTr).BodyPart(2).X)].^2 + [0; diff(vtd(iTr).BodyPart(2).Y)].^2);
speed = (speed - min(speed))/(max(speed) - min(speed));
plot(hAxes, vtd(iTr).Time, speed, 'b')
hold off