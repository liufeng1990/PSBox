%   Author: Ying Xiong.
%   Created: Jan 24, 2014.

%% Setup parameters.
% Change the 'topDir' to your local data directory.
topDir = fullfile(fileparts(mfilename('fullpath')), 'data');
% The format of output (decoded) RAW images.
rawOutSuffix = 'png';
% The image channel used to perform photometric stereo.
imgChannel = 1;
% The intensity threshold for shadow, in [0, 1].
shadowThresh = 0.1;

%% Rename the input images.
% Copy the input images from 'Original' to 'OriginalRenamed', so that one can
% keep the 'Original' folder intact.
% Uncomment following block to rename input images.
%{
fprintf('Rename input images...\n');
originalFilePattern = 'IMG_%04d';
originalFileIndices = [7518:7521, 7523:7524, 7526:7531];
originalRefIndex = 7532;
PSRenameInputImages(topDir, originalFilePattern, originalFileIndices, ...
                    originalRefIndex);
%}

%% Derender the RAW images.
% Go to the 'OriginalRenamed' folder and run the following command
%   'dcraw -v -4 -h -o 0 -r 1 1 1 1 -T *.CR2'
% You can also change the output *.tiff files to other format you prefer, say
% *.png, and change the 'rawOutSuffix' accordingly.

%% Create bounding boxes.
% Create a 'ManualData' folder, and create following files
%   obj_bbox.txt: the bounding box for the object, 4x1 vector, referenced
%                 from the 'Image_NN.tiff' images. A bbox is specified as
%                     x_min x_max y_min y_max
%   probes_bbox.txt: the bounding box for two light probes, 4x2 matrix,
%                    referenced from the 'ref.JPG' image.
%   circle_{1,2}_pts.txt: the points on the circle of each light probe, Nx2
%                         matrix, referenced from the 'ref.JPG' image
%                             x1  y1
%                             x2  y2
%                             ......
% Note that the y-direction of the coordinate system should be reverted when
% collecting these data. See README.txt for more information.

%% Crop the object and light probe.
% Uncomment following block to crop images.
%{
fprintf('Cropping images...\n');
PSCropImages(topDir, rawOutSuffix);
%}

%% Fit the light probe circle.
fprintf('Fitting light probe circles...\n');
PSFitLightProbeCircle(topDir);

%% Find the lighting directions.
fprintf('Finding light directions...\n');
PSFindLightDirection(topDir);

%% Load data into memory and prepare to do photometric stereo.

fprintf('Loading data into memory...\n');
% Load lighting directions.
L1 = textread(fullfile(topDir, 'LightProbe-1', 'light_directions.txt'));
L2 = textread(fullfile(topDir, 'LightProbe-2', 'light_directions.txt'));
L = normc(L1+L2);

% Load images.
objDir = fullfile(topDir, 'Objects');
imgFiles = dir(fullfile(objDir, ['Image_*.' rawOutSuffix]));
nImgs = length(imgFiles);
I = imread(fullfile(objDir, imgFiles(1).name));
[M, N, C] = size(I);

I = zeros(M, N, nImgs);
for i = 1:nImgs
  Itmp = im2double(imread(fullfile(objDir, imgFiles(i).name)));
  Itmp = Itmp(end:-1:1, :, imgChannel);
  % Normalize over the 99 percentile. This makes sense when the object is of of
  % uniform albedo.
  I(:,:,i) = Itmp / prctile(Itmp(:), 99);
end

% Create a shadow mask.
shadow_mask = (I > shadowThresh);
se = strel('disk', 5);
for i = 1:nImgs
  % Erode the shadow map to handle de-mosaiking artifact near shadow boundary.
  shadow_mask(:,:,i) = imerode(shadow_mask(:,:,i), se);
end

%% Do the photometric stereo.
fprintf('Running photometric stereo...\n');
[rho, n] = PhotometricStereo(I, shadow_mask, L);

% Visualize the normal map.
figure; imshow(n); axis xy;

fprintf('Done.\n');