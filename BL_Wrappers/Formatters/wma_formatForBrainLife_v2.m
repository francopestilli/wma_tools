function  wma_formatForBrainLife_v2(classification,fg)
%    function wma_formatForBrainLife()
%
%   Shamelessly stolen from brain-life/app-tractclassification
%
%   This function takes the output from segmentation type scripts /
%   applications (i.e. ones that output classification structures) and
%   formats them for use on the brainlife platform

if ~isdeployed
    disp('\n adding paths');
    addpath(genpath('/N/soft/rhel7/spm/8')) %spm needs to be loaded before vistasoft as vistasoft provides anmean that works
    addpath(genpath('/N/u/brlife/git/encode'))
    addpath(genpath('/N/u/brlife/git/jsonlab'))
    addpath(genpath('/N/u/brlife/git/vistasoft'))
    addpath(genpath('/N/u/brlife/git/wma_tools'))
end

%saving again, just for good measure
mkdir(fullfile(pwd,'classification'));
savepath=strcat(pwd,'/classification/classification.mat');
save(savepath,'classification');

fg_classified = bsc_makeFGsFromClassification_v4(classification, fg);

config = loadjson('config.json');

if ~isfield(config,'track')
    alltracks= fgCreate();
   for itracts=1:length(classification.names)
       alltracks = fgMerge(alltracks,fg_classified{itracts},'alltracts');
       %tck unused
       tck = dtiExportFibersMrtrix(alltracks, 'track.tck');
   end
end

mkdir('classification/tracts');

% Make colors for the tracts
classificationGrouped=wma_classificationStrucGrouping(classification);
neededColors=length(classificationGrouped.names);
smallCM = distinguishable_colors(neededColors,'k');

%find names and appropriate order for tracts
for iTracts=1:length(fg_classified)
nameList{iTracts}=fg_classified{iTracts}.name;
end

%create a color vector with color pairings in the correct locations
for iGroups=1:length(classificationGrouped.names)
    curIndexes=bsc_extractStreamIndByName(classificationGrouped,classificationGrouped.names{iGroups});
    curNames={classification.names{unique(classification.index(curIndexes))}};
    for iNames=1:length(curNames)
        namePlace=find(strcmp(curNames{iNames},nameList));
      cm(namePlace,:)=smallCM(iGroups,:);
    end
end  
    
for it = 1:length(fg_classified)
    tract.name   = fg_classified{it}.name;
    tract.color  = cm(it,:);
    
    %pick randomly up to 1000 fibers (pick all if there are less than 1000)
    fiber_count = min(1000, numel(fg_classified{it}.fibers));
    tract.coords = cellfun(@(x) round(x,3), fg_classified{it}.fibers(randperm(fiber_count)), 'UniformOutput', false);

    
    all_tracts(it).name = fg_classified{it}.name;
    all_tracts(it).color = cm(it,:);
    savejson('', tract, fullfile('classification/tracts',sprintf('%i.json',it)));
    all_tracts(it).filename = sprintf('%i.json',it);
    clear tract
end


savejson('', all_tracts, fullfile('classification/tracts/tracts.json'));
%WHY WAS THIS DELETING THE CLASSIFICATION
%delete('classification.mat')
% Save the results to disk
save('output.mat','fg_classified','classification','-v7.3');
classification
% save product.json information
tract_info = cell(length(fg_classified), 2);
fibercounts = zeros(1, length(fg_classified));
possible_error = 0;
num_left_tracts = 0;
num_right_tracts = 0;

for i = 1 : length(fg_classified)
    name = fg_classified{i}.name;
    num_fibers = length(fg_classified{i}.fibers);
    
    fibercounts(i) = num_fibers;
    tract_info{i,1} = name;
    tract_info{i,2} = num_fibers;
    
    if startsWith(name, 'Right ') || endsWith(name, ' R')
        num_right_tracts = num_right_tracts + 1;
    else
        num_left_tracts = num_left_tracts + 1;
    end
    
    if num_fibers < 20
        possible_error = 1;
    end
end

left_tract_xs = cell(1, num_left_tracts);
right_tract_xs = cell(1, num_right_tracts);

left_tract_ys = zeros([1, num_left_tracts]);
right_tract_ys = zeros([1, num_right_tracts]);

left_tract_idx = 1;
right_tract_idx = 1;

for i = 1 : length(fg_classified)
    name = fg_classified{i}.name;
    num_fibers = length(fg_classified{i}.fibers);
    basename = name;
    
    if startsWith(basename, 'Right ')
        basename = extractAfter(basename, 6);
    end
    if endsWith(basename, ' R')
        basename = extractBefore(basename, length(basename) - 1);
    end
    
    if startsWith(basename, 'Left ')
        basename = extractAfter(basename, 5);
    end
    if endsWith(basename, ' L')
        basename = extractBefore(basename, length(basename) - 1);
    end
    
    if startsWith(name, 'Right ') || endsWith(name, ' R')
        right_tract_xs{right_tract_idx} = basename;
        right_tract_ys(right_tract_idx) = num_fibers;
        right_tract_idx = right_tract_idx + 1;
    else
        left_tract_xs{left_tract_idx} = basename;
        left_tract_ys(left_tract_idx) = num_fibers;
        left_tract_idx = left_tract_idx + 1;
    end
end

bar1 = struct;
bar2 = struct;

bar1.x = left_tract_xs;
bar1.y = left_tract_ys;
bar1.type = 'bar';
bar1.name = 'Left Tracts';
bar1.marker = struct;
bar1.marker.color = 'rgb(49,130,189)';

bar2.x = right_tract_xs;
bar2.y = right_tract_ys;
bar2.type = 'bar';
bar2.name = 'Right Tracts';
bar2.marker = struct;
bar2.marker.color = 'rgb(204, 204, 204)';

bardata = {bar1, bar2};
barlayout = struct;
barlayout.xaxis = struct;
barlayout.xaxis.tickfont = struct;
barlayout.xaxis.tickfont.size = 8;

barlayout.barmode = 'group';
barplot = struct;
barplot.data = bardata;
barplot.layout = barlayout;
barplot.type = 'plotly';
barplot.name = 'Number of Fibers';

T = cell2table(tract_info);
T.Properties.VariableNames = {'Tracts', 'FiberCount'};

writetable(T, 'output_fibercounts.txt');

% bar graph

% box plot

boxplot = struct;

boxplot.data = struct;
boxplot.layout = struct;
boxplot.type = 'plotly';
boxplot.name = 'Fiber Counts';

boxplot.data.x = fibercounts;
boxplot.data.type = 'box';
boxplot.data.name = 'Number of Fibers';
boxplot.data = {boxplot.data};

boxplot.layout.title = 'Fiber Counts';

product = {barplot, boxplot};
if possible_error == 1
    message = struct;
    message.type = 'error';
    message.msg = 'ERROR: Some tracts have less than 20 streamlines. Check quality of data!';
    product = {barplot, boxplot, message};
end
savejson('brainlife', product, 'product.json');

end
