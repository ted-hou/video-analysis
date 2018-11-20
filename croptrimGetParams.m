% Select dirs
dirs = uipickfiles('Prompt', 'Select (multiple) folders...');
dirs = dirs(isfolder(dirs));

% Trim videos, generate new timestamps and crop videos
Params = struct([]);
applyCropParamsToAll = [];
for iDir = 1:length(dirs)
	try
		foldername 	= strsplit(dirs{iDir}, '\');
		foldername 	= foldername{end};
		vidFiles 	= dir([dirs{iDir}, '\*.mp4']);
		matFile 	= [dirs{iDir}, '\', foldername, '.mat'];
		% Check if videos and mat files exist
		if isempty(vidFiles)
			error(['Skipping folder (', foldername, ') - no video file inside.']);
		end
		if ~exist(matFile, 'file')
			error(['Skipping folder (', foldername, ') - no ArduinoConnection mat file inside.']);
		end

		dirname = vidFiles(1).folder;
		vidFiles = cellfun(@(filename) [dirname, '\', filename], {vidFiles.name}, 'UniformOutput', false);
		vidFiles = vidFiles(cellfun(@(x) isempty(strfind(x, '_cropped')), vidFiles)); % Filter out videos that are already cropped.

		% Store video file name
		Params(iDir).Video(1).File = vidFiles{1}(1:end-4);
		Params(iDir).Video(2).File = vidFiles{2}(1:end-4);

		% Retrieve alignment param
		% TODO: handle more than 2 videos
		load(matFile, 'obj');
		% Time is stored as number of *days* since a start point. This simply will not suffice. The Grad Student must elect to have it converted to seconds.
		t1 		= [obj.Cameras(1).Camera.EventLog.Timestamp];
		t2 		= [obj.Cameras(2).Camera.EventLog.Timestamp];
		frame1 	= [obj.Cameras(1).Camera.EventLog.FrameNumber];
		frame2 	= [obj.Cameras(2).Camera.EventLog.FrameNumber];

		% Discard the first datapoint (timestamp for frame 0 is not accurate)
		t1 		= t1(2:end);
		t2 		= t2(2:end);
		frame1 	= frame1(2:end);
		frame2 	= frame2(2:end);

		% Upsample to get timestamps for each frame
		frame1Up = frame1(1):frame1(end);
		frame2Up = frame2(1):frame2(end);
		t1Up = interp1(frame1, t1, frame1Up);
		t2Up = interp1(frame2, t2, frame2Up);

		% Find a common starting point & trim the longer video
		% Usually, video 1 starts first so trim the start of video 1
		if t1Up(1) < t2Up(1)
			[~, i] = min(abs(t1Up - t2Up(1)));
			t1Up = t1Up(i:end);
			frame1Up = frame1Up(i:end);
		elseif t1Up(1) > t2Up(1)
			[~, i] = min(abs(t2Up - t1Up(1)));
			t2Up = t2Up(i:end);
			frame2Up = frame2Up(i:end);
		end

		% Find a common end point & trim the longer video
		% Usually, video 1 ends first so trim the end of video 2
		if t1Up(end) < t2Up(end)
			[~, i] = min(abs(t2Up - t1Up(end)));
			t2Up = t2Up(1:i);
			frame2Up = frame2Up(1:i);
		elseif t1Up(end) > t2Up(end)
			[~, i] = min(abs(t1Up - t2Up(end)));
			t1Up = t1Up(1:i);
			frame1Up = frame1Up(1:i);
		end

		% Store trim params
		Params(iDir).Video(1).FrameNumber = frame1Up;
		Params(iDir).Video(2).FrameNumber = frame2Up;
		Params(iDir).Video(1).Timestamp = datetime(t1Up, 'ConvertFrom', 'datenum', 'TimeZone', 'America/New_York');
		Params(iDir).Video(2).Timestamp = datetime(t2Up, 'ConvertFrom', 'datenum', 'TimeZone', 'America/New_York');

		% Prompt for video cropping
		% First video
		if isempty(applyCropParamsToAll)
			answer = questdlg('Use the same crop limits for all videos?');
			switch lower(answer)
				case 'yes'
					applyCropParamsToAll = true;
				case 'no'
					applyCropParamsToAll = false;
				case 'cancel'
					warning('The Grad Student has chosen shenanigans over working. What a shameful display! :(')
					return
			end
			for iVid = 1:length(vidFiles)
				vid = VideoReader(vidFiles{iVid});
				hFigure(iVid) = figure('Name', vidFiles{iVid});
				hAxes = axes(hFigure(iVid));
				img = read(vid, 1);
				image(hAxes, img);
				axis(hAxes, 'image');
				hRect(iVid) = drawrectangle(hAxes, 'Deletable', false, 'Position', [0.5, 0.5, size(img, 2), size(img, 1)]);
			end
			input('Say something nice to me to continue...\n', 's');
			crop = round(transpose(reshape([hRect.Position], 4, [])));
			Params(iDir).Video(1).Crop = crop(1, :);
			Params(iDir).Video(2).Crop = crop(2, :);
			close(hFigure)
		% Selected 'use individual crop params'
		elseif (islogical(applyCropParamsToAll) && ~applyCropParamsToAll)
			for iVid = 1:length(vidFiles)
				vid = VideoReader(vidFiles{iVid});
				hFigure(iVid) = figure('Name', vidFiles{iVid});
				hAxes = axes(hFigure(iVid));
				img = read(vid, 1);
				image(hAxes, img);
				axis(hAxes, 'image');
				hRect(iVid) = drawrectangle(hAxes, 'Deletable', false, 'Position', [0.5, 0.5, size(img, 2), size(img, 1)]);
			end
			input('Say something nice to me to continue...\n', 's');
			Params(iDir).Video(1).Crop = crop(1, :);
			Params(iDir).Video(2).Crop = crop(2, :);
			close(hFigure)
		% Using previous crop params
		elseif (islogical(applyCropParamsToAll) && applyCropParamsToAll)
			Params(iDir).Video(1).Crop = Params(iDir - 1).Video(1).Crop;
			Params(iDir).Video(2).Crop = Params(iDir - 1).Video(2).Crop;
		end
	catch ME
		warning(['Error processing folder "', dirs{iDir}, '". This one will be skipped.'])
		warning(sprintf('Error in program %s.\nTraceback (most recent at top):\n%s\nError Message:\n%s', mfilename, getcallstack(ME), ME.message))
	end
end
