%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function ecModel = modifyKcats(ecModel,ecModel_const,gRexp,modified_kcats,name)
%
% Function that gets the limiting Kcat values in an EC model (according to
% a sensitivity analysis), then it modifies each of those values according to 
% the maximal available values in the BRENDA files (Kcats and SA*Mw) when a
% manual curated option is not specified.
% 
% The algorithm iterates until the model grows at the same rate provided 
% by the user (batch growth on glucose minimal media recommended)
%
% INPUTS
%   - ecModel:       Enzyme-constrained GEM 
%   - ecModel_const: Enzyme-constrained GEM with the total protein pool
%                    global constraint.
%   - gRexp:         Maximal experimental growth rate on glucose minimal 
%                    media for simulation outputs comparison
%   - modified_kcats: Cell array containing IDs for the previously manually 
%                    modified kcats ('UniprotCode_rxnIndex')
%   - name:          String containing the name for the model files
%                    provided by the user.
% OUTPUTS
%   - ecModel:       Enzyme-constrained GEM with the automatically curated
%                    Kinetic parameters.
%
% Ivan Domenzain    Last edited. 2018-03-18
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ecModel = modifyKcats(ecModel,ecModelBatch,gRexp,modified_kcats,name)
    
    modifications  = []; error = -100; i=1; current = pwd; 
    %Load BRENDA data:
    cd ../get_enzyme_data
    [BRENDA,SA_cell] = loadBRENDAdata;
    cd ../kcat_sensitivity_analysis
    %Iterates while growth rate is being underpredicted
    disp('********************Limiting Kcats curation********************')
    % Tolerance of 5% underprediction for allowing a sigma factor 
    % readjustment
    while error<=-5
        cd (current)
        %Get the top growth rate-limiting enzyme (uniprot code basis)
        [limKcat,breakFlag] = findTopLimitations(ecModelBatch,modified_kcats,0);
        
        if breakFlag == false
            disp(['*Iteration #' num2str(i)])
            [ecModelBatch,data] = changeKcat(ecModelBatch,limKcat,gRexp,...
                                                         BRENDA,SA_cell);
                                          
            cd (current)
            %Saves the parameter modification information
            modifications = [modifications; data];
            if ~isempty(data{1,9})
                error = data{1,9};
            end
            %Add a string with the uniprot code and the rxn number in order
            %to keep track of the modified coefficients
            str            = {horzcat(data{1},'_',num2str(limKcat{3}))};
            modified_kcats = [modified_kcats; str];
            disp(horzcat('  Protein:',data{1},' Rxn#:',num2str(limKcat{1,3}), ...
                                                  ' name: ',limKcat{6}{1}))
                                              
            disp(['  prev_Kcat:' num2str(data{1,7}) ' new_Kcat:' ...
                  num2str(data{1,8}) ' gRCC:' num2str(limKcat{1,5}) ...
                                                   ' Err:' num2str(error) '%'])            
            i = i+1;            
        else
            break
        end
        fprintf('\n')
    end  
    cd (current)
    %Create a .txt file with all the modifications that were done on the
    %individual Kcat coefficients
    if ~isempty(modifications)
        [m,n]         = size(ecModel.S);
        ecModel.S     = ecModelBatch.S(1:m,1:n);
        varNamesTable = {'Unicode','enz_pos','rxn_pos','Organism',...
                         'Modified','Parameter','oldValue','newValue',...
                         'error','gRControlCoeff'};

        modifications = cell2table(modifications,'VariableNames',varNamesTable);
        modifications = truncateValues(modifications,4);
        writetable(modifications,['../../models/' name '/data/' name '_kcatModifications.txt']);
        
    else
        %If the model is not growing then the analysis is performed in all
        %the Kcats matched either to: option 1 -> each of the enzymatic
        %rxns, option 2 -> each of the individual enzymes
        [limRxns,~] = findTopLimitations(ecModelBatch,modified_kcats,1);
        [limEnz, ~] = findTopLimitations(ecModelBatch,modified_kcats,2);

        if ~isempty(limRxns)
            varNamesTable = {'rxnNames','rxnPos','gRControlCoeff'};
            modifications = cell2table(limRxns,'VariableNames',varNamesTable);
            modifications = truncateValues(modifications,4);
            writetable(modifications,['../../models/' name '/data/' name '_limitingRxns.txt']);
        end
        if ~isempty(limEnz)
            varNamesTable = {'EnzNames','EnzPos','gRControlCoeff'};
            modifications = cell2table(limEnz,'VariableNames',varNamesTable);
            modifications = truncateValues(modifications,4);
            writetable(modifications,['../../models/' name '/data/' name '_limitingEnzymes.txt']);
        end
    end
        
     
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [model,data] = changeKcat(model,limKcats,gR_exp,BRENDA,SA_cell)
   % Gets the Unicode 
    UniCode = limKcats{1}{1}(strfind(limKcats{1}{1},'_')+1:end);
    % Map the UNIPROT code (kcat)
    [ECnumber, ~] = findECnumber(UniCode);
    enzIndx       = limKcats{2}(1);
    rxnIndx       = limKcats{3}(1);
    data          = {UniCode,[],[],[],[],[],[],[],[],[]};
    error         = 0;
    
    if ~isempty(ECnumber)
    	flag           = false;
    	previous_value = -1/(3600*model.S(enzIndx,rxnIndx)); %[1/s]
        
            disp([' Automatic search // ' 'EC#: ' ECnumber])
           %Looks for the maximal value available for the respective EC
           %number (Kcats and SA*Mw if available)
            [Kcat,org, match] = findMaxValue(ECnumber,BRENDA,SA_cell);
            coeff             = -1/(Kcat);  
           %Change the kinetic coefficient just if a higher value was found
            if coeff > model.S(enzIndx,rxnIndx)
            	flag = true;
                model.S(enzIndx,rxnIndx) = coeff;
            end
        new_value = -1/(3600*model.S(enzIndx,rxnIndx));
           
        % After changing the i-th kcat limiting value a simulation is
        % performed and the growth rate and absolute error are saved 
        model_sim            = model;
        gR_pos               = find(strcmpi(model_sim.rxnNames,'growth'));
        model_sim.c          = zeros(size(model_sim.c));
        model_sim.c(gR_pos)  = 1;
        solution             = solveLP(model_sim);
        model_sim.lb(gR_pos) = 0.999*solution.x(gR_pos);
        model_sim.ub(gR_pos) = solution.x(gR_pos);
        solution             = solveLP(model_sim,1);

        error  = ((solution.x(gR_pos)-gR_exp)/gR_exp)*100;
        data   = {UniCode,limKcats{2}(1),limKcats{3}(1),org,flag,match,...
                            previous_value,new_value,error,limKcats{5}(1)};  
   end 
         
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function  [ECnumber, Mw] = findECnumber(Unicode)
    current = pwd;
    load ('../../databases/ProtDatabase.mat')
    DB1{1} = swissprot(:,1);DB1{2} = swissprot(:,4);DB1{3} = swissprot(:,5);
    DB2{1} = kegg(:,1);     DB2{2} = kegg(:,4);     DB2{3} = kegg(:,5);
    ECnumber = {};
    Mw       = {};
    % First look for the UNIPROT ID in the swissprot DB structure
    matching = find(strcmpi(DB1{1},Unicode));
    if ~isempty(matching)
        ECnumber = DB1{2}{matching};
        Mw       = DB1{3}{matching};
    end
    % If nothing comes up then look into the KEGG DB structure
    if isempty(ECnumber)
        matching = find(strcmpi(DB2{1},Unicode));
        if ~isempty(matching)
            ECnumber = DB2{2}{matching};
            Mw       = DB2{3}{matching};
        end
    end
    cd (current)
end
