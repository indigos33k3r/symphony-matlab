classdef NewEpochGroupPresenter < symphonyui.Presenter
    
    properties (Access = private)
        experiment
        preferences
    end
    
    methods
        
        function obj = NewEpochGroupPresenter(experiment, preferences, view)
            if nargin < 2
                preferences = symphonyui.Configurations.epochGroupPreference();
                preferences.setToDefaults();
            end
            if nargin < 3
                view = symphonyui.views.NewEpochGroupView([]);
            end
            
            obj = obj@symphonyui.Presenter(view);
            
            obj.experiment = experiment;
            obj.preferences = preferences;
            
            obj.addListener(view, 'AddExternalSolution', @obj.onSelectedAddExternalSolution);
            obj.addListener(view, 'RemoveExternalSolution', @obj.onSelectedRemoveExternalSolution);
            obj.addListener(view, 'AddInternalSolution', @obj.onSelectedAddInternalSolution);
            obj.addListener(view, 'RemoveInternalSolution', @obj.onSelectedRemoveInternalSolution);
            obj.addListener(view, 'AddOther', @obj.onSelectedAddOther);
            obj.addListener(view, 'RemoveOther', @obj.onSelectedRemoveOther);
            obj.addListener(view, 'Begin', @obj.onSelectedBegin);
            obj.addListener(view, 'Cancel', @(h,d)obj.view.close);
        end
        
    end
    
    methods (Access = protected)
        
        function onViewShown(obj, ~, ~)            
            onViewShown@symphonyui.Presenter(obj);
            
            obj.view.setWindowKeyPressFcn(@obj.onWindowKeyPress);
            obj.view.setLabelList(obj.preferences.labelList);
            obj.view.setRecordingList(obj.preferences.recordingList);
            obj.view.setAvailableExternalSolutionList(obj.preferences.availableExternalSolutionList);
            obj.view.setAvailableInternalSolutionList(obj.preferences.availableInternalSolutionList);
            obj.view.setAvailableOtherList(obj.preferences.availableOtherList);
        end
        
    end
    
    methods (Access = private)
        
        function onWindowKeyPress(obj, ~, data)
            if strcmp(data.Key, 'return')
                obj.onSelectedBegin();
            elseif strcmp(data.Key, 'escape')
                obj.view.close();
            end
        end
        
        function onSelectedAddExternalSolution(obj, ~, ~)
            c = obj.view.getAvailableExternalSolution();
            if ~ischar(c)
                return;
            end
            added = obj.view.getAddedExternalSolutionList();
            if any(ismember(added, c))
                return;
            end
            obj.view.setAddedExternalSolutionList([added;{c}]);
        end
        
        function onSelectedRemoveExternalSolution(obj, ~, ~)
            c = obj.view.getAddedExternalSolution();
            if ~ischar(c)
                return;
            end
            added = obj.view.getAddedExternalSolutionList();
            index = ismember(added, c);
            added(index) = [];
            obj.view.setAddedExternalSolutionList(added);
        end
        
        function onSelectedAddInternalSolution(obj, ~, ~)
            c = obj.view.getAvailableInternalSolution();
            if ~ischar(c)
                return;
            end
            added = obj.view.getAddedInternalSolutionList();
            if any(ismember(added, c))
                return;
            end
            obj.view.setAddedInternalSolutionList([added;{c}]);
        end
        
        function onSelectedRemoveInternalSolution(obj, ~, ~)
            c = obj.view.getAddedInternalSolution();
            if ~ischar(c)
                return;
            end
            added = obj.view.getAddedInternalSolutionList();
            index = ismember(added, c);
            added(index) = [];
            obj.view.setAddedInternalSolutionList(added);
        end
        
        function onSelectedAddOther(obj, ~, ~)
            c = obj.view.getAvailableOther();
            if ~ischar(c)
                return;
            end
            added = obj.view.getAddedOtherList();
            if any(ismember(added, c))
                return;
            end
            obj.view.setAddedOtherList([added;{c}]);
        end
        
        function onSelectedRemoveOther(obj, ~, ~)
            c = obj.view.getAddedOther();
            if ~ischar(c)
                return;
            end
            added = obj.view.getAddedOtherList();
            index = ismember(added, c);
            added(index) = [];
            obj.view.setAddedOtherList(added);
        end
        
        function onSelectedBegin(obj, ~, ~)
            drawnow();
            
            label = obj.view.getLabel();
            recording = obj.view.getRecording();
            keywords = obj.view.getKeywords();
            source = [];
            
            attributes = [];
            
            obj.experiment.beginEpochGroup(label, source, keywords, attributes);
            
            obj.view.result = true;
        end
        
    end
    
end

