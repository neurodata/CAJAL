function cubeUploadDense(server, token, channel, RAMONVol, protoRAMON, useSemaphore, varargin)

% **Inputs**
%
% server: (string)
%   - OCP server name serving as the target for annotations
%
% token: (string)
%   - OCP token name serving as the target for annotations
%
% channel: (string)
%   - OCP channel name serving as the target for annotations
%
% RAMONVol: (string)
%   - Location of output file, saved as a matfile containing a RAMONVolume named 'cube'
%
% protoRAMON (string)
%   - RAMONObject prototype to apply to all object types
%
% useSemaphore: (int)(default=0)
%   - throttles reading/writing client-side for large batch jobs.  Not needed in single cutout mode
%
% outputFile: (string)
%   - optional file path to store output volume as a RAMONVolume named 'cube'
%
% **Outputs**
%
%	No explicit outputs.  Output file is optionally saved to disk rather
%	than output as a variable to allow for downstream integration with
%	LONI.
%
% **Notes**
%
% Function to upload objects in a RAMON volume as a denseVolume
% Requires that all objects begin from a common prototype, and that
% RAMONVolume has appropriate fields (in particular resolution and XYZ
% offset).  This only supports anno32 data for now - do not use for probability
% uploads.  Centroids have been added to this function by popular request.

if nargin > 6
    outFile = varargin{1};
end

if useSemaphore
    oo = OCP('semaphore');
else
    oo = OCP;
end

oo.setServerLocation(server);
oo.setAnnoToken(token);
oo.setAnnoChannel(channel);

% Load data volume
if ischar(RAMONVol)
    load(RAMONVol) %should be saved as cube
else
    cube = RAMONVol;
end


%% Upload to OCP

% relabel Paint
fprintf('Relabling: ');
labels = uint32(cube.data); %TODO - loss of precision if nid > 2^32
[zz, n] = relabel_id(labels);

rp = regionprops(zz,'Centroid');


if n > 0
% Create empty RAMON Objects

obj_cell = cell(n,1);
for ii = 1:n
    obj_cell{ii} = eval(protoRAMON);
    cVal = round(rp(ii).Centroid+cube.xyzOffset)-[1,1,1];
    obj_cell{ii}.addDynamicMetadata('centroid',cVal);
end

% Batch write RAMON Objects
tic
oo.setBatchSize(100);
ids = oo.createAnnotation(obj_cell);
fprintf('Batch Metadata Upload: ');
toc

labelOut = zeros(size(zz));

rp = regionprops(zz,'PixelIdxList');
for ii = 1:length(rp)
    labelOut(rp(ii).PixelIdxList) = ids(ii);
end

clear zz

% Block write paint
tic

% Reuse object
cube.setCutout(labelOut);
cube.setDataType(eRAMONChannelDataType.uint32); %just in case
cube.setChannelType(eRAMONChannelType.annotation);
cube.setChannel(channel);

oo.createAnnotation(cube);
fprintf('Block Write Upload: ');
toc
else
    disp('no labels found...skipping upload!')
end

if exist('outFile')
save(outFile,'cube')
end
