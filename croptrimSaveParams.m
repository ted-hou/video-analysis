for iParam = 1:length(Params)
	numVids = length(Params(iParam).Video);
	for iVid = 1:numVids
		thisVid = Params(iParam).Video(iVid);
		File 	= thisVid.File;
		Frame 	= thisVid.FrameNumber;
		Time 	= thisVid.Timestamp;
		Crop 	= thisVid.Crop;
		save([Params(iParam).Video(iVid).File, '_vidparams'], 'File', 'Frame', 'Time', 'Crop');
	end
end