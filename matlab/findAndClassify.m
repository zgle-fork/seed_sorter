function [ fit, resultImage, bwImage, seedVector] = findAndClassify( inputImage, sideLength, classificationModel )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

%% Init
% defaults
cellSize = [8, 8];
blockSize = [2, 2];
blockOverlap = ceil(blockSize/2);
numBins = 9;


blocksPerImage = floor(([sideLength, sideLength]./cellSize - blockSize)./(blockSize - blockOverlap) + 1);
hogN = prod([blocksPerImage, blockSize, numBins]);

%% Segmentation
% 
% 
h_image = rgb2hsv(inputImage);
threshold = graythresh(h_image(:,:,2));

se = strel('disk',2);
s_bw = imbinarize(medfilt2(h_image(:,:,2)), threshold*1);
% h_bw = ~imbinarize(medfilt2(h_image(:,:,1)), h_threshold*1);

iBW = imclose(imopen(s_bw, se), se);
bwImage = iBW;

%Fish Eye Fix 
% imgray = rgb2gray(inputImage);
% imSize = size(imgray);
% subSize = floor(imSize*0.7);
% difSize = floor((imSize - subSize)/2);
% threshold = graythresh(imgray(difSize(1):(end-difSize(1)), ...
%     difSize(2):(end-difSize(2))))*1.2;



%%
% Old Segmentation
% imgray = rgb2gray(inputImage);
% % Fisheye fix
% imSize = size(imgray);
% subSize = floor(imSize*0.7);
% difSize = floor((imSize - subSize)/2);
% threshold = graythresh(imgray(difSize(1):(end-difSize(1)), ...
%     difSize(2):(end-difSize(2))))*1.2;
% % threshold = 0.8;
% iBW = imbinarize(medfilt2(imgray),threshold);
% 
% %iBW = bwareaopen(iBW, 300);
% iBW = bwareaopen(iBW, 200);
% bwImage = iBW;
% 
% % imshow(iBW)
% % iBWS = iBW;
% % 
% % mask = cat(3, iBW, iBW, iBW);
% % iBWS(mask == 0) = 0;
% % imshow(iBWS)

%% Features compute

imCC = bwconncomp(iBW);
labels = labelmatrix(imCC);

bbs = regionprops(imCC, 'BoundingBox');
orientations = regionprops(imCC, 'Orientation');
centroids = regionprops(imCC, 'Centroid');

featureVectors = zeros(hogN, imCC.NumObjects);

if imCC.NumObjects >= 1
    for i=1:imCC.NumObjects
        bb = bbs(i).BoundingBox;
        x = round(bb(1));
        y = round(bb(2));
        if bb(3) > bb(4)
            padding = floor((bb(3) - bb(4))/2);
            y = max(y - padding, 1);
            bb(4) = bb(4) + 2*padding + floor(bb(3) - bb(4)) - 2*padding;
        elseif bb(4) > bb(3)
            padding = floor((bb(4) - bb(3))/2);
            x = max(x - padding, 1);
            bb(3) = bb(3) + 2*padding + floor(bb(4) - bb(3)) - 2*padding;
        end
        % Better border check and size fit
        subI = zeros(bb(4), bb(4), 3, 'uint8');
        subL = zeros(bb(4), bb(4), 'uint8');
        maxY = min(size(inputImage, 1), y + bb(4));
        maxX = min(size(inputImage, 2), x + bb(3));
        
        
        %
        subI(1:(maxY - y + 1), 1:(maxX - x + 1),:) = inputImage(y:maxY, x:maxX, :);
        subL(1:(maxY - y + 1), 1:(maxX - x + 1)) = labels(y:maxY, x:maxX);
        mask = subL == i;
        mask(:,:,2) = mask(:,:,1);
        mask(:,:,3) = mask(:,:,1);
        
        maskedSubI = subI;
        maskedSubI(~mask) = 0;
        
        maskedSubI = imrotate(maskedSubI, -orientations(i).Orientation);
        s = sideLength/size(maskedSubI,1);
        
        %Old resizing
%       maskedSubI = imresize(maskedSubI, s);
        %New resizing
        maskedSubI = imresize(maskedSubI, [60 60]);
        
        
        featureVectors(:, i) = extractHOGFeatures(maskedSubI);
    end
end

%% Classify
fit = classificationModel.predictFcn(featureVectors');

%%
texts = cell(imCC.NumObjects,1);
positions = zeros(imCC.NumObjects, 2);
% seedVector : 
% Vecteur avec la position du grain et son identifiant:
% (X,Y,type) 
% type = 0 pour Mais, type = 1 pour Soya 

seedVector = zeros(imCC.NumObjects, 3);

for i = 1:imCC.NumObjects
    c = centroids(i).Centroid;
    c = round(c);
    if fit(i) == 0
        texts{i} = 'Corn';
        seedVector(i,3) = 0;
    else
        texts{i} = 'Soy';
        seedVector(i,3) = 1;
    end
    positions(i,:) = c;
    seedVector(i,1:2) =c;
end
if isempty(positions)
    resultImage = [];
    return
end
% resultImage = insertText(label2rgb(labels), positions, texts);
resultImage = insertText(inputImage, positions, texts);
resultImage = insertText(resultImage, [0,10], ['Otsu Threshold = ', num2str(threshold)]);
% resultImage = iBW;
end

