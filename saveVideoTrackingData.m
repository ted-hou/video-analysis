function saveVideoTrackingData(VTD)
	for iVid = 1:length(VTD)
		vtd = VTD(1);
		file = [vtd.File, '_VideoTrackingData.mat'];
		save(file, 'vtd')
	end
