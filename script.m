datetime.setDefaultFormats('default','yyyy-MM-dd hh:mm:ss.SSSS Z')

cd('D:\DeepLabCut\videos')
vtd = getVideoTrackingData();
[tr, vtd] = loadTetrodeRecording(vtd);

for iTr = 1:length(tr)
	disp(['NEV Time - ', datestr(tr(iTr).GetStartTime())]);
	disp(['MP4 Time - ', datestr(vtd(iTr).Time(1))]);
end