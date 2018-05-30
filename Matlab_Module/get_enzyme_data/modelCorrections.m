%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% model = modelCorrections(model)
% Corrects various issues in yeast 7.
%
% INPUT:    A yeast model as a .mat structure.
% OUTPUT:   The corrected model.
%
% Benjam�n J. S�nchez. Last edited: 2018-05-28
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function model = modelCorrections(model)

%Correct glucan coefficients in biomass reaction:
model.S(strcmp(model.mets,'s_0002'),strcmp(model.rxns,'r_4041')) = 0;
model.S(strcmp(model.mets,'s_0001'),strcmp(model.rxns,'r_4041')) = -0.8506;
model.S(strcmp(model.mets,'s_0004'),strcmp(model.rxns,'r_4041')) = -0.2842;

%Correctly represent proton balance inside cell:
model.lb(strcmp(model.rxns,'r_1824')) = 0;  %Block free H+ export
model.ub(strcmp(model.rxns,'r_1250')) = 0;  %Block free putrescine export
model.ub(strcmp(model.rxns,'r_1259')) = 0;  %Block free spermidine export

%CHANGES IN OX.PHO.:
%COMPLEX III: H+ pumping corrected for eff P/O ratio:
eff = 0.633;     %Growth in glucose S.cerevisiae Verduyn 1991
model.S(strcmp(model.mets,'s_0799'),strcmp(model.rxns,'r_0439')) = -2*eff;
model.S(strcmp(model.mets,'s_0794'),strcmp(model.rxns,'r_0439')) = +4*eff;
%COMPLEX IV: H+ pumping corrected for eff P/O ratio:
model.S(strcmp(model.mets,'s_0799'),strcmp(model.rxns,'r_0438')) = -8*eff;
model.S(strcmp(model.mets,'s_0794'),strcmp(model.rxns,'r_0438')) = +4*eff;
%COMPLEX IV: Normalize rxn by the number of ferrocytochromes c:
rxn_pos            = strcmp(model.rxns,'r_0438');
ferro_S            = abs(model.S(strcmp(model.mets,'s_0710'),rxn_pos));
model.S(:,rxn_pos) = model.S(:,rxn_pos)./ferro_S;
%COMPLEX V: For 1 ATP 3 H+ are needed, not 4:
model.S(strcmp(model.mets,'s_0799'),strcmp(model.rxns,'r_0226')) = +2;
model.S(strcmp(model.mets,'s_0794'),strcmp(model.rxns,'r_0226')) = -3;

%Delete blocked rxns (LB = UB = 0):
to_remove = boolean((model.lb == 0).*(model.ub == 0));
model     = removeRxns(model,model.rxns(to_remove));

%Correct rev vector: true if LB < 0 & UB > 0 (and it's not an exchange reaction):
model.rev = false(size(model.rxns));
for i = 1:length(model.rxns)
    if (model.lb(i) < 0 && model.ub(i) > 0) || ...
       ~isempty(strfind(model.rxnNames{i},'exchange'))
        model.rev(i) = true;
    end
end

%Add geneNames from swissprot:
data      = load('../../Databases/ProtDatabase.mat');
swissprot = data.swissprot(:,3);
model.geneNames = cell(size(model.genes));
for i = 1:length(swissprot)
    swissprot{i} = strsplit(swissprot{i},' ');
    for j = 1:length(model.genes)
        if ismember(model.genes{j},swissprot{i})
            model.geneNames{j} = swissprot{i}{1}; %First occurence is the gene name
            disp(['Adding gene names: Ready with gene ' model.genes{j}])
        end
    end
end

%Delete empty fields of model that won't be used later:
model = rmfield(model,'metCharge');
model = rmfield(model,'subSystems');
model = rmfield(model,'confidenceScores');
model = rmfield(model,'rxnReferences');
model = rmfield(model,'rxnECNumbers');
model = rmfield(model,'rxnNotes');
model = rmfield(model,'metChEBIID');
model = rmfield(model,'metKEGGID');
model = rmfield(model,'metPubChemID');
model = rmfield(model,'metInChIString');

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%