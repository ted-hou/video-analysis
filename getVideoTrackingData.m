function VideoTrackingData = getVideoTrackingData()
	[files, dirname] = uigetfile('C:\SERVER\VideoTracking\*.csv', 'MultiSelect', 'on');
	numFiles = length(files);
	split = cellfun(@(x) strsplit(x, '_'), files, 'UniformOutput', false);

	for iFile = 1:numFiles
		fprintf('Loading file %d/%d...', iFile, numFiles)

		thisMouse = split{iFile}{1};
		thisDate = split{iFile}{2};
		if length(split{iFile}) < 7
			thisFile = dir(['C:\SERVER\**\', thisMouse, '_', thisDate, '_vidparams.mat']);
		else
			thisCamera = split{iFile}{3};
			thisFile = dir(['C:\SERVER\**\', thisMouse, '_', thisDate, '_', thisCamera, '_vidparams.mat']);
		end

		% Find corresponding crop/trim param file on server
		thisFile = [thisFile.folder, '\', thisFile.name];
		S = load(thisFile);

		VideoTrackingData(iFile).File = S.File;
		VideoTrackingData(iFile).Frame = S.Frame;
		VideoTrackingData(iFile).Time = S.Time;
		VideoTrackingData(iFile).Crop = S.Crop;

		% Load csv
		thisData = importdata([dirname, files{iFile}]);
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
		fprintf('Done!\n')
	end
