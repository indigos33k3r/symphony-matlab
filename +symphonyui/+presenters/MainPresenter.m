classdef MainPresenter < symphonyui.Presenter
    
    properties (Access = private)
        appData
        parametersPresenter
    end
    
    methods
        
        function obj = MainPresenter(preferences, view)            
            if nargin < 2
                view = symphonyui.views.MainView();
            end
            
            obj = obj@symphonyui.Presenter(view);
            %view.loadPosition();
            
            obj.appData = symphonyui.AppData(preferences);
            obj.addListener(obj.appData, 'SetRig', @obj.onSetRig);
            obj.addListener(obj.appData, 'SetExperiment', @obj.onSetExperiment);
            obj.addListener(obj.appData, 'SetProtocol', @obj.onSetProtocol);
            obj.addListener(obj.appData, 'SetProtocolList', @obj.onSetProtocolList);
            obj.addListener(obj.appData, 'SetControllerState', @obj.onSetControllerState);
            
            obj.addListener(view, 'NewExperiment', @obj.onSelectedNewExperiment);
            obj.addListener(view, 'CloseExperiment', @obj.onSelectedCloseExperiment);
            obj.addListener(view, 'BeginEpochGroup', @obj.onSelectedBeginEpochGroup);
            obj.addListener(view, 'EndEpochGroup', @obj.onSelectedEndEpochGroup);
            obj.addListener(view, 'SelectedProtocol', @obj.onSelectedProtocol);
            obj.addListener(view, 'ProtocolParameters', @obj.onSelectedProtocolParameters);
            obj.addListener(view, 'Run', @obj.onSelectedRun);
            obj.addListener(view, 'Pause', @obj.onSelectedPause);
            obj.addListener(view, 'Stop', @obj.onSelectedStop);
            obj.addListener(view, 'SetRig', @obj.onSelectedSetRig);
            obj.addListener(view, 'Preferences', @obj.onSelectedPreferences);
            obj.addListener(view, 'Documentation', @obj.onSelectedDocumentation);
            obj.addListener(view, 'UserGroup', @obj.onSelectedUserGroup);
            obj.addListener(view, 'AboutSymphony', @obj.onSelectedAboutSymphony);
            obj.addListener(view, 'Exit', @(h,d)view.close());
            
            view.enableNewExperiment(false);
            view.enableCloseExperiment(false);
            view.enableBeginEpochGroup(false);
            view.enableEndEpochGroup(false);
            view.enableAddNote(false);
            view.enableViewNotes(false);
            view.enableViewRig(false);
            view.enableSelectProtocol(false);
            view.enableProtocolParameters(false);
            view.enableRun(false);
            view.enablePause(false);
            view.enableStop(false);
            view.enableShouldSave(false);
            view.enableStatus(false);
            
            obj.onSetProtocolList();
        end
        
    end
    
    methods (Access = private)
        
        function onSelectedNewExperiment(obj, ~, ~)
            view = symphonyui.views.NewExperimentView(obj.view);
            p = symphonyui.presenters.NewExperimentPresenter(obj.appData.experimentPreferences, view);
            result = p.view.showDialog();
            if result
                obj.appData.setExperiment(p.experiment);
            end
        end
        
        function onSelectedCloseExperiment(obj, ~, ~)
            obj.appData.experiment.close();
            obj.appData.setExperiment([]);
        end
        
        function onSetExperiment(obj, ~, ~)
            hasExperiment = ~isempty(obj.appData.experiment);
            
            obj.view.enableNewExperiment(~hasExperiment);
            obj.view.enableCloseExperiment(hasExperiment);
            obj.view.enableBeginEpochGroup(hasExperiment);
            obj.view.enableAddNote(hasExperiment);
            obj.view.enableViewNotes(hasExperiment);
            obj.view.enableSetRig(~hasExperiment);
            obj.view.enableShouldSave(hasExperiment);
            obj.view.setShouldSave(hasExperiment);
        end
        
        function onSelectedBeginEpochGroup(obj, ~, ~)
            experiment = obj.appData.experiment;
            preferences = obj.appData.epochGroupPreferences;
            view = symphonyui.views.NewEpochGroupView(obj.view);
            p = symphonyui.presenters.NewEpochGroupPresenter(experiment, preferences, view);
            p.view.showDialog();
        end
        
        function onBeganEpochGroup(obj, ~, ~)
            obj.view.enableEndEpochGroup(true);
        end
        
        function onSelectedEndEpochGroup(obj, ~, ~)
            obj.appData.experiment.endEpochGroup();
        end
        
        function onEndedEpochGroup(obj, ~, ~)
            if isempty(obj.appData.experiment.epochGroup)
                obj.view.enableEndEpochGroup(false);
            end
        end
        
        function onSelectedAddNote(obj, ~, ~)
            disp('Selected Add Note');
        end
        
        function onSelectedViewNotes(obj, ~, ~)
            disp('Selected View Notes');
        end
        
        function onSelectedProtocol(obj, ~, ~)
            p = obj.view.getProtocol();
            obj.appData.setProtocol(p);
        end
        
        function onSetProtocol(obj, ~, ~)
            hasProtocol = ~isempty(obj.appData.protocol);
            
            obj.view.enableProtocolParameters(hasProtocol);
            obj.view.setProtocol(obj.appData.getProtocolName);
            
            if ~isempty(obj.parametersPresenter)
                if hasProtocol
                    obj.parametersPresenter.setProtocol(obj.appData.protocol);
                else
                    obj.parametersPresenter.view.close();
                end
            end
        end
        
        function onSetProtocolList(obj, ~, ~)
            obj.view.setProtocolList(obj.appData.getProtocolList);
        end
        
        function onSelectedProtocolParameters(obj, ~, ~)
            if isempty(obj.parametersPresenter)
                v = symphonyui.views.ProtocolParametersView(obj.view);
                obj.parametersPresenter = symphonyui.presenters.ProtocolParametersPresenter(v);
                obj.addListener(obj.parametersPresenter.view, 'Closing', @obj.onProtocolPresenterClosing);                
                obj.parametersPresenter.setProtocol(obj.appData.protocol);
            end
            obj.parametersPresenter.view.show();
        end
        
        function onProtocolPresenterClosing(obj, ~, ~)
            obj.parametersPresenter = [];
        end
        
        function onSelectedRun(obj, ~, ~)
            p = obj.appData.protocol;
            obj.appData.controller.runProtocol(p);
        end
        
        function onSelectedPause(obj, ~, ~)
            obj.appData.controller.pause();
        end
        
        function onSelectedStop(obj, ~, ~)
            obj.appData.controller.stop();
        end
        
        function onSetControllerState(obj, ~, ~)
            import symphonyui.models.*;
            
            enableRun = false;
            enablePause = false;
            enableStop = false;
            enableShouldSave = false;
            enableStatus = false;
            status = 'Unknown';
            
            switch obj.appData.controller.state
                case ControllerState.NOT_READY
                    status = 'Not Ready';
                case ControllerState.STOPPED
                    enableRun = true;
                    enableShouldSave = true;
                    enableStatus = true;
                    status = 'Stopped';
                case ControllerState.STOPPING
                    enableStatus = true;
                    status = 'Stopping';
                case ControllerState.PAUSED
                    enableRun = true;
                    enableStop = true;
                    enableShouldSave = true;
                    enableStatus = true;
                    status = 'Paused';
                case ControllerState.PAUSING
                    enableStop = true;
                    enableStatus = true;
                    status = 'Pausing';
                case ControllerState.RUNNING
                    enablePause = true;
                    enableStop = true;
                    enableStatus = true;
                    status = 'Running';
            end
            
            obj.view.enableRun(enableRun);
            obj.view.enablePause(enablePause);
            obj.view.enableStop(enableStop);
            obj.view.enableShouldSave(enableShouldSave && ~isempty(obj.appData.experiment));
            obj.view.enableStatus(enableStatus);
            obj.view.setStatus(status);
        end
        
        function onSelectedSetRig(obj, ~, ~)
            list = obj.appData.getRigList();
            view = symphonyui.views.SetRigView(obj.view);
            p = symphonyui.presenters.SetRigPresenter(list, view);
            result = p.view.showDialog();
            if result
                obj.appData.setRig(p.rig);
            end
        end
        
        function onSetRig(obj, ~, ~)
            hasRig = ~isempty(obj.appData.rig);
            
            obj.view.enableViewRig(hasRig);
            obj.view.enableNewExperiment(hasRig);
            obj.view.enableSelectProtocol(hasRig);
            
            if hasRig
                obj.onSelectedProtocol();
            end
        end
        
        function onSelectedPreferences(obj, ~, ~)
            preferences = obj.appData.preferences;
            view = symphonyui.views.AppPreferencesView(obj.view);
            p = symphonyui.presenters.AppPreferencesPresenter(preferences, view);
            p.view.showDialog();
        end
        
        function onSelectedDocumentation(obj, ~, ~)
            web('https://github.com/Symphony-DAS/Symphony/wiki');
        end
        
        function onSelectedUserGroup(obj, ~, ~)
            web('https://groups.google.com/forum/#!forum/symphony-das');
        end
        
        function onSelectedAboutSymphony(obj, ~, ~)
            p = symphonyui.presenters.AboutSymphonyPresenter('2.0.0-preview');
            p.view.showDialog();
        end
        
    end
    
    methods (Access = protected)
        
        function onViewClosing(obj, ~, ~)
            onViewClosing@symphonyui.Presenter(obj);
            obj.view.savePosition();
        end
        
    end
    
end
