function saveVideoTrackingData(VTD)
	for iVid = 1:length(VTD)
		vtd = VTD(iVid);
		file = [vtd.File, '_VideoTrackingData.mat'];
		save(file, 'vtd')
	end
