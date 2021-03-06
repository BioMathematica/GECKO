%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% [ecModel,model_data,kcats] = enhanceGEM(model,toolbox,name,version)
%
% Benjamín J. Sánchez & Ivan Domenzain. Last edited: 2018-08-11
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ecModel,model_data,kcats] = enhanceGEM(model,toolbox,name,version)

%Provide your organism scientific name
org_name = 'saccharomyces cerevisiae';
format short e
initCobraToolbox

%Add RAVEN fields for easier visualization later on:
cd get_enzyme_data
if strcmp(toolbox,'COBRA')
    model = ravenCobraWrapper(model);
end

%Remove blocked rxns + correct model.rev:
model = preprocessModel(model);

%Retrieve kcats & MWs for each rxn in model:
model_data = getEnzymeCodes(model);
kcats      = matchKcats(model_data,org_name);
save(['../../models/' name '/data/' name '_enzData.mat'],'model_data','kcats','version')

%Integrate enzymes in the model:
cd ../change_model
ecModel                 = readKcatData(model_data,kcats);
[ecModel,modifications] = manualModifications(ecModel);

%Constrain model to batch conditions:
sigma  = 0.5;      %Optimized for glucose
Ptot   = 0.5;      %Assumed constant
gR_exp = 0.41;     %[g/gDw h] Max batch gRate on minimal glucose media
cd ../limit_proteins
[ecModel_batch,OptSigma] = getConstrainedModel(ecModel,sigma,Ptot,gR_exp,modifications,name);
disp(['Sigma factor (fitted for growth on glucose): ' num2str(OptSigma)])

%Save output models:
cd ../../models
ecModel = saveECmodel(ecModel,toolbox,name,version);
saveECmodel(ecModel_batch,toolbox,[name '_batch'],version);
cd ../geckomat

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
