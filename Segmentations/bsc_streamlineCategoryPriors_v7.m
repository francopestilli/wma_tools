function [classificationOut] =bsc_streamlineCategoryPriors_v7(wbfg, atlas,inflateITer)
%[classificationOut] =bsc_streamlineCategoryPriors_v7(wbfg, atlas,inflateITer)
%
% This function automatedly segments a whole brain tractogram into
% antomically based categories (fronto-frontal, etc).  Provides a
% classificaiton structure that assigns category membership to each
% streamline.  Serves as a good basis for coarse comparison between
% tractograms.  Also serves as a good initial subcategorization of
% streamlines which can be used in subsequent segmentations
%
% Inputs:
% -wbfg: a whole brain fiber group structure
% -atlas: path to THIS SUBJECT'S freesurfer directory
%
% Outputs:
%  classificationOut:  standardly constructed classification structure
%
% (C) Daniel Bullock, 2020, Indiana University

%% parameter note & initialization

% loads object if path passed
if ischar(wbfg)
wbfg = fgRead(wbfg);
else
    %do nothing
end
fprintf('\n NOTE: All label numbers cited are from DK2009 \n')
[superficialClassification] =bsc_segmentSuperficialFibers_v3(wbfg, atlas);

greyMatterROIS=[[101:1:175]+12000 [101:1:175]+11000];
leftROIS=[[101:1:175]+11000 26  17 18 7 8 10:13];
rightROIS=[[101:1:175]+12000 46 47 49:54 58];

subcorticalROIS=[ 20   27 56 59 ];
spineROIS=[16 28 60];
cerebellumROIS=[8 47 7 46 ];
ventricleROIS=[31 63 11 50 4 43 14 24 15 44 5 62 30 80 72 ];
wmROIS=[41 2];
ccROIS=[251:255];
unknownROIS=[0 2000 1000 77:82 24 42 3];
OpticCROI=[85];

FrontalROIs=[[124 148 165 101 154 105 115 154 155 115 170 129 146 153 ...
    164 106 116 108 131 171 112 150 104 169 114 113 116 107 163 139 132 140]+11000 [124 148 165 101 154 105 115 154 155 115 170 129 146 153 ...
    164 106 116 108 131 171 112 150 104 169 114 113 116 107 163 139 132 140]+12000] ;

TemporalROIs=[[144 134 138 137 173 174 135 175 121 151 123 162 133]+11000 [144 134 138 137 173 174 135 175 121 151 123 162 133]+12000];

OccipitalROI=[[120 119 111 158 166 143 145 159 152 122 162 161 121 160 102]+11000 [120 119 111 158 166 143 145 159 152 122 162 161 121 160 102]+12000];

ParietalROI=[[157 127 168 136 126 125 156 128 141 172 147 109 103 130 110]+11000 [157 127 168 136 126 125 156 128 141 172 147 109 103 130 110]+12000];

pericROI=[[167]+11000 [167]+12000];

insulaROI=[ 19 [117 118 149]+11000 55 [117 118 149]+12000];

thalamicROI=[10 ; 49];

caudateNAcROI=[26 11; 50 58];

lenticularNROI=[12 13 ; 51 52];

hippAmig=[17 18; 53 54 ];

roiGroupNames={'subcorticalROIS','spineROIS','cerebellumROIS','ventricleROIS','wmROIS','ccROIS','unknownROIS','OpticCROI','FrontalROIs','TemporalROIs','OccipitalROI','ParietalROI','pericROI','insulaROI','thalamicROI','caudateNAcROI','lenticularNROI','hippAmig' };
roiGroups={subcorticalROIS,spineROIS,cerebellumROIS,ventricleROIS,wmROIS,ccROIS,unknownROIS,OpticCROI,FrontalROIs,TemporalROIs,OccipitalROI,ParietalROI,pericROI,insulaROI,thalamicROI,caudateNAcROI,lenticularNROI,hippAmig};
labelsPresent=unique(atlas.data);

%do a one time warning about which rois are missing
fprintf('\n freesurfer ROI report for:')
fprintf('\n %s \n',atlas.fname)
for iRoiGroups=1:length(roiGroups)
    currentRoiNums=roiGroups{iRoiGroups};
    currentMissing=~ismember(currentRoiNums,labelsPresent);
    if any(currentMissing)
        fprintf('\n labels %s missing for roi group %s',num2str(currentRoiNums(currentMissing)),roiGroupNames{iRoiGroups})
    else
        %do nothing, they are all there
    end
end
fprintf('\n')

fprintf('\n rois set')

%atlasPath=fullfile(fsDir,'/mri/','aparc.a2009s+aseg.nii.gz');

if inflateITer>0
    [inflatedAtlas] =bsc_inflateLabels_v3(atlas,inflateITer);
else
    inflatedAtlas=atlas;
end


%to account for streamlines that cross and then come back
leftROI=bsc_roiFromAtlasNums(inflatedAtlas,leftROIS,1);
rightROI=bsc_roiFromAtlasNums(inflatedAtlas,rightROIS,1);
[~, leftStreamsBool]=wma_SegmentFascicleFromConnectome(wbfg, {leftROI}, {'and'}, 'dud');
[~, rightStreamsBool]=wma_SegmentFascicleFromConnectome(wbfg, {rightROI}, {'and'}, 'dud');

allStreams=wbfg.fibers;
clear wbfg
%initialize classification structure
classificationOut=[];
classificationOut.names=[];
classificationOut.index=zeros(length(allStreams),1);


classificationMid=classificationOut;


endpoints1=zeros(3,length(allStreams));
endpoints2=zeros(3,length(allStreams));


for icategories=1:length(allStreams)
    curStream=allStreams{icategories};
    endpoints1(:,icategories)=curStream(:,1);
    endpoints2(:,icategories)=curStream(:,end);
end

fprintf('\n endpoints extracted')


[endpoints1Identity] =bsc_atlasROINumsFromCoords_v3(inflatedAtlas,endpoints1,'acpc');
[counts1, groups1]=groupcounts(endpoints1Identity);
for iUnknownRois=1:length(unknownROIS)
    fprintf('\n %i endpoints for label %i in RAS group',counts1(iUnknownRois),groups1(iUnknownRois))
end
unknownSum1= sum(counts1(ismember(groups1,unknownROIS)));
fprintf('\n')
if unknownSum1/length(allStreams)>.05
    warning('Proportion of unknown streamlines exceeds 5% for RAS endpoints')
end

[endpoints2Identity] =bsc_atlasROINumsFromCoords_v3(inflatedAtlas,endpoints2,'acpc');
[counts2, groups2]=groupcounts(endpoints2Identity);
for iUnknownRois=1:length(unknownROIS)
    fprintf('\n %i endpoints for label %i in LPI group',counts2(iUnknownRois),groups2(iUnknownRois))
end
unknownSum2= sum(counts2(ismember(groups2,unknownROIS)));
fprintf('\n')
if unknownSum2/length(allStreams)>.05
    warning('Proportion of unknown streamlines exceeds 5% for LPI endpoints')
end


fprintf('\n endpoint identities determined')


excludeBool=zeros(1,length(allStreams));
includeBool=excludeBool;
LeftBool=excludeBool;
RightBool=excludeBool;
implausBool=excludeBool;
interHemiBool=excludeBool;
validUIndexes=excludeBool;
bothSides=excludeBool;
singleLeftBoolproto=excludeBool;
singleRightBoolproto=excludeBool;
interhemiFlag=excludeBool;
termination2=cell(1,length(allStreams));
termination1=cell(1,length(allStreams));
streamName=termination1;



fprintf('\n superficial fibers identified')

validSideROI= [leftROIS rightROIS] ;
excludeSideROI=[unknownROIS ccROIS OpticCROI wmROIS spineROIS ventricleROIS pericallosal];

for iStreams=1:length(allStreams)
    %disagreeBool(iStreams)=or(and(rightStreamsBool(iStreams),and(ismember(endpoints2Identity(iStreams),leftROIS),ismember(endpoints1Identity(iStreams),leftROIS))),and(leftStreamsBool(iStreams),and(ismember(endpoints2Identity(iStreams),rightROIS),ismember(endpoints1Identity(iStreams),rightROIS))))  ;
    excludeBool(iStreams)=or(ismember(endpoints2Identity(iStreams),excludeSideROI),ismember(endpoints1Identity(iStreams),excludeSideROI));
    includeBool(iStreams)=or(ismember(endpoints2Identity(iStreams),validSideROI),ismember(endpoints1Identity(iStreams),validSideROI));
    validUIndexes(iStreams)=or(ismember(endpoints2Identity(iStreams),greyMatterROIS),ismember(endpoints1Identity(iStreams),greyMatterROIS))&~excludeBool(iStreams);
    LeftBool(iStreams)=and(ismember(endpoints2Identity(iStreams),leftROIS),ismember(endpoints1Identity(iStreams),leftROIS));
    RightBool(iStreams)=and(ismember(endpoints2Identity(iStreams),rightROIS),ismember(endpoints1Identity(iStreams),rightROIS));
    interHemiBool(iStreams)=or(and(ismember(endpoints2Identity(iStreams),leftROIS),ismember(endpoints1Identity(iStreams),rightROIS)),and(ismember(endpoints2Identity(iStreams),rightROIS),ismember(endpoints1Identity(iStreams),leftROIS)));
    implausBool(iStreams)=and(~interHemiBool(iStreams),and(leftStreamsBool(iStreams),rightStreamsBool(iStreams)));
    
    
    singleLeftBoolproto(iStreams)=xor(ismember(endpoints2Identity(iStreams),leftROIS),ismember(endpoints1Identity(iStreams),leftROIS));
    singleRightBoolproto(iStreams)=xor(ismember(endpoints2Identity(iStreams),rightROIS),ismember(endpoints1Identity(iStreams),rightROIS));
    
    
    if     ~isempty(find(endpoints1Identity(iStreams)==FrontalROIs, 1))
        termination1{iStreams}='frontal';
    elseif ~isempty(find(endpoints1Identity(iStreams)==TemporalROIs, 1))
        termination1{iStreams}='temporal';
    elseif ~isempty(find(endpoints1Identity(iStreams)==OccipitalROI, 1))
        termination1{iStreams}='occipital';
    elseif ~isempty(find(endpoints1Identity(iStreams)==ParietalROI, 1))
        termination1{iStreams}='parietal';
    elseif ~isempty(find(endpoints1Identity(iStreams)==subcorticalROIS, 1))
        termination1{iStreams}='subcortical';
    elseif ~isempty(find(endpoints1Identity(iStreams)==thalamicROI, 1))
        termination1{iStreams}='thalamic';
    elseif ~isempty(find(endpoints1Identity(iStreams)==caudateNAcROI, 1))
        termination1{iStreams}='caudateNAc';
    elseif ~isempty(find(endpoints1Identity(iStreams)==lenticularNROI, 1))
        termination1{iStreams}='lenticularN';
    elseif ~isempty(find(endpoints1Identity(iStreams)==hippAmig, 1))
        termination1{iStreams}='hippAmig';
    elseif ~isempty(find(endpoints1Identity(iStreams)==spineROIS, 1))
        termination1{iStreams}='spinal';
    elseif ~isempty(find(endpoints1Identity(iStreams)==insulaROI, 1))
        termination1{iStreams}='insula';
    elseif ~isempty(find(endpoints1Identity(iStreams)==cerebellumROIS, 1))
        termination1{iStreams}='cerebellum';
    elseif ~isempty(find(endpoints1Identity(iStreams)==ccROIS, 1))
        termination1{iStreams}='CorpusCallosum';
        %false positives
    elseif ~isempty(find(endpoints1Identity(iStreams)==ventricleROIS, 1))
        termination1{iStreams}='ventricle';
    elseif ~isempty(find(endpoints1Identity(iStreams)==unknownROIS, 1))
        termination1{iStreams}='unlabeled';
    elseif ~isempty(find(endpoints1Identity(iStreams)==wmROIS, 1))
        termination1{iStreams}='whiteMatter';
    elseif ~isempty(find(endpoints1Identity(iStreams)==pericROI, 1))
        termination1{iStreams}='pericallosal';
    elseif ~isempty(find(endpoints1Identity(iStreams)==OpticCROI, 1))
        termination1{iStreams}='OpticChi';
    end
    
    if     ~isempty(find(endpoints2Identity(iStreams)==FrontalROIs, 1))
        termination2{iStreams}='frontal';
    elseif ~isempty(find(endpoints2Identity(iStreams)==TemporalROIs, 1))
        termination2{iStreams}='temporal';
    elseif ~isempty(find(endpoints2Identity(iStreams)==OccipitalROI, 1))
        termination2{iStreams}='occipital';
    elseif ~isempty(find(endpoints2Identity(iStreams)==ParietalROI, 1))
        termination2{iStreams}='parietal';
    elseif ~isempty(find(endpoints2Identity(iStreams)==subcorticalROIS, 1))
        termination2{iStreams}='subcortical';
    elseif ~isempty(find(endpoints2Identity(iStreams)==thalamicROI, 1))
        termination2{iStreams}='thalamic';
    elseif ~isempty(find(endpoints2Identity(iStreams)==caudateNAcROI, 1))
        termination2{iStreams}='caudateNAc';
    elseif ~isempty(find(endpoints2Identity(iStreams)==lenticularNROI, 1))
        termination2{iStreams}='lenticularN';
    elseif ~isempty(find(endpoints2Identity(iStreams)==hippAmig, 1))
        termination2{iStreams}='hippAmig';
    elseif ~isempty(find(endpoints2Identity(iStreams)==spineROIS, 1))
        termination2{iStreams}='spinal';
    elseif ~isempty(find(endpoints2Identity(iStreams)==insulaROI, 1))
        termination2{iStreams}='insula';
    elseif ~isempty(find(endpoints2Identity(iStreams)==cerebellumROIS, 1))
        termination2{iStreams}='cerebellum';
        %false positives
    elseif ~isempty(find(endpoints2Identity(iStreams)==pericROI, 1))
        termination2{iStreams}='pericallosal';
    elseif ~isempty(find(endpoints2Identity(iStreams)==ventricleROIS, 1))
        termination2{iStreams}='ventricle';
    elseif ~isempty(find(endpoints2Identity(iStreams)==unknownROIS, 1))
        termination2{iStreams}='unlabeled';
    elseif ~isempty(find(endpoints2Identity(iStreams)==wmROIS, 1))
        termination2{iStreams}='whiteMatter';
    elseif ~isempty(find(endpoints2Identity(iStreams)==ccROIS, 1))
        termination2{iStreams}='CorpusCallosum';
    elseif ~isempty(find(endpoints2Identity(iStreams)==OpticCROI, 1))
        termination2{iStreams}='OpticChi';
    end
    
    
    if ~or(isempty(termination1{iStreams}),isempty(termination2{iStreams}))
        terminationNames=sort({termination1{iStreams} termination2{iStreams}});
    else
        endpoints1Identity(iStreams)
        endpoints2Identity(iStreams)
        error('streamline identity unaccounted for')
    end
    
    
    
    %hierarchy of categories here
    interhemiFlag(iStreams)=interHemiBool(iStreams)&includeBool(iStreams);
    if interhemiFlag(iStreams)
        streamName{iStreams}=strcat(terminationNames{1},'_to_',terminationNames{2},'_interHemi');
    else
        streamName{iStreams}=strcat(terminationNames{1},'_to_',terminationNames{2});
    end
    
    
    if superficialClassification.index(iStreams)>0&validUIndexes(iStreams)
        streamName{iStreams}=strcat(terminationNames{1},'_to_',terminationNames{2},'_ufiber');
    end
    
    if or(LeftBool(iStreams),singleLeftBoolproto(iStreams))&includeBool(iStreams)&~interhemiFlag(iStreams)
        streamName{iStreams}=strcat('left_',streamName{iStreams});
    elseif or(RightBool(iStreams),singleRightBoolproto(iStreams))&includeBool(iStreams)&~interhemiFlag(iStreams)
        streamName{iStreams}=strcat('right_',streamName{iStreams});
    end
    
    if interhemiFlag(iStreams)&validUIndexes(iStreams)&~superficialClassification.index(iStreams)==0
        streamName{iStreams}=strcat('MaskFailure');
    end
    
    if implausBool(iStreams)
        streamName{iStreams}=strcat(streamName{iStreams},'_implausable');
    else
        %do nothing
    end
    
end

uniqueNames=unique(streamName);

fprintf('\n %i endpoint categories determined', length(uniqueNames))

summarizeNames={'CorpusCallosum' 'unlabeled' 'OpticChi' 'ventricle' 'whiteMatter' 'pericallosal'};

for icategories=1:length(uniqueNames)
    
    if contains(uniqueNames{icategories},summarizeNames)
        for isummary=1:length(summarizeNames)
            summaryIndex(isummary)=contains(uniqueNames{icategories},summarizeNames{isummary});
        end
        summaryIndexSingle=find(summaryIndex);
        classificationOut=bsc_concatClassificationCriteria(classificationOut,summarizeNames{summaryIndexSingle(1)},contains(streamName,uniqueNames{icategories}));
        clear summaryIndex
    else
        classificationOut=bsc_concatClassificationCriteria(classificationOut,uniqueNames{icategories},ismember(streamName,uniqueNames{icategories}));
    end
end


classificationOut = wma_resortClassificationStruc(classificationOut);

fprintf('\n categorical segmentation complete')
end