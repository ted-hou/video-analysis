function VideoTrackingData = getVideoTrackingData()
	csvlist = dir('*.csv');
	csvlist = csvlist(~[csvlist.isdir]);
	numFiles = length(csvlist);
	split = cellfun(@(x) strsplit(x, '_'), {csvlist.name}, 'UniformOutput', false);

	for iFile = 1:numFiles
		thisMouse = split{iFile}{1};
		thisDate = split{iFile}{2};
		thisCamera = split{iFile}{3};

		% Find corresponding crop/trim param file on server
		thisFile = dir(['C:\SERVER\**\', thisMouse, '_', thisDate, '_', thisCamera, '_vidparams.mat']);
		thisFile = [thisFile.folder, '\', thisFile.name];
		S = load(thisFile);

		VideoTrackingData(iFile).File = S.File;
		VideoTrackingData(iFile).Frame = S.Frame;
		VideoTrackingData(iFile).Time = S.Time;
		VideoTrackingData(iFile).Crop = S.Crop;

		% Load csv
		thisData = importdata(csvlist(iFile).name);
		numBodyParts = (size(thisData.data, 2) - 1)/3;
		bodyPartNames = strsplit(thisData.textdata{2, 1}, ',');
		for iBodyPart = 1:numBodyParts
			iCol = 2 + 3*(iBodyPart - 1);
			thisBodyPartName = bodyPartNames{iCol};
			VideoTrackingData(iFile).BodyPart(iBodyPart).Name = thisBodyPartName;
			VideoTrackingData(iFile).BodyPart(iBodyPart).X = thisData.data(:, iCol);
			VideoTrackingData(iFile).BodyPart(iBodyPart).Y = thisData.data(:, iCol + 1);
			VideoTrackingData(iFile).BodyPart(iBodyPart).Likelihood = thisData.data(:, iCol + 2);
		end
	end
