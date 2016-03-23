classdef DataManagerPresenter < appbox.Presenter

    properties
        viewSelectedCloseFcn
    end

    properties (Access = private)
        log
        settings
        documentationService
        acquisitionService
        uuidToNode
        detailedEntitySet
    end

    methods

        function obj = DataManagerPresenter(documentationService, acquisitionService, view)
            if nargin < 3
                view = symphonyui.ui.views.DataManagerView();
            end
            obj = obj@appbox.Presenter(view);

            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.settings = symphonyui.ui.settings.DataManagerSettings();
            obj.documentationService = documentationService;
            obj.acquisitionService = acquisitionService;
            obj.detailedEntitySet = symphonyui.core.persistent.collections.EntitySet();
            obj.uuidToNode = containers.Map();
        end

    end

    methods (Access = protected)

        function willGo(obj)
            obj.populateEntityTree();
            try
                obj.loadSettings();
            catch x
                obj.log.debug(['Failed to load presenter settings: ' x.message], x);
            end
            obj.updateStateOfControls();
        end

        function willStop(obj)
            try
                obj.saveSettings();
            catch x
                obj.log.debug(['Failed to save presenter settings: ' x.message], x);
            end
        end

        function bind(obj)
            bind@appbox.Presenter(obj);

            v = obj.view;
            obj.addListener(v, 'SelectedNodes', @obj.onViewSelectedNodes);
            obj.addListener(v, 'AddSource', @obj.onViewSelectedAddSource);
            obj.addListener(v, 'SetSourceLabel', @obj.onViewSetSourceLabel);
            obj.addListener(v, 'SetExperimentPurpose', @obj.onViewSetExperimentPurpose);
            obj.addListener(v, 'BeginEpochGroup', @obj.onViewSelectedBeginEpochGroup);
            obj.addListener(v, 'EndEpochGroup', @obj.onViewSelectedEndEpochGroup);
            obj.addListener(v, 'SetEpochGroupLabel', @obj.onViewSetEpochGroupLabel);
            obj.addListener(v, 'SelectedEpochSignal', @obj.onViewSelectedEpochSignal);
            obj.addListener(v, 'SetProperty', @obj.onViewSetProperty);
            obj.addListener(v, 'AddProperty', @obj.onViewSelectedAddProperty);
            obj.addListener(v, 'RemoveProperty', @obj.onViewSelectedRemoveProperty);
            obj.addListener(v, 'AddKeyword', @obj.onViewSelectedAddKeyword);
            obj.addListener(v, 'RemoveKeyword', @obj.onViewSelectedRemoveKeyword);
            obj.addListener(v, 'AddNote', @obj.onViewSelectedAddNote);
            obj.addListener(v, 'SendEntityToWorkspace', @obj.onViewSelectedSendEntityToWorkspace);
            obj.addListener(v, 'DeleteEntity', @obj.onViewSelectedDeleteEntity);
            obj.addListener(v, 'OpenAxesInNewWindow', @obj.onViewSelectedOpenAxesInNewWindow);

            d = obj.documentationService;
            obj.addListener(d, 'AddedSource', @obj.onServiceAddedSource);
            obj.addListener(d, 'BeganEpochGroup', @obj.onServiceBeganEpochGroup);
            obj.addListener(d, 'EndedEpochGroup', @obj.onServiceEndedEpochGroup);
            obj.addListener(d, 'DeletedEntity', @obj.onServiceDeletedEntity);

            a = obj.acquisitionService;
            obj.addListener(a, 'ChangedControllerState', @obj.onServiceChangedControllerState);
        end

        function onViewSelectedClose(obj, ~, ~)
            if ~isempty(obj.viewSelectedCloseFcn)
                obj.viewSelectedCloseFcn();
            end
        end

    end

    methods (Access = private)

        function populateEntityTree(obj)
            experiment = obj.documentationService.getExperiment();
            if isempty(experiment.purpose)
                name = datestr(experiment.startTime, 1);
            else
                name = [experiment.purpose ' [' datestr(experiment.startTime, 1) ']'];
            end
            obj.view.setExperimentNode(name, experiment);
            obj.uuidToNode(experiment.uuid) = obj.view.getExperimentNode();

            sources = experiment.sources;
            for i = 1:numel(sources)
                obj.addSourceNode(sources{i});
            end
            obj.view.expandNode(obj.view.getSourcesFolderNode());

            groups = experiment.epochGroups;
            for i = 1:numel(groups)
                obj.addEpochGroupNode(groups{i});
            end
            obj.view.expandNode(obj.view.getEpochGroupsFolderNode());
            
            obj.view.setSelectedNodes(obj.uuidToNode(experiment.uuid));
            obj.populateToolbarForExperiments(experiment);
            obj.populateDetailsForExperiments(experiment);
        end

        function onViewSelectedAddSource(obj, ~, ~)
            selectedParent = [];
            nodes = obj.view.getSelectedNodes();
            if numel(nodes) == 1 && obj.view.getNodeType(nodes(1)) == symphonyui.ui.views.EntityNodeType.SOURCE
                selectedParent = obj.view.getNodeEntity(nodes(1));
            end

            presenter = symphonyui.ui.presenters.AddSourcePresenter(obj.documentationService, selectedParent);
            presenter.goWaitStop();
        end

        function onServiceAddedSource(obj, ~, event)
            source = event.data;
            node = obj.addSourceNode(source);

            obj.view.stopEditingProperties();
            obj.view.update();
            obj.view.setSelectedNodes(node);
            
            obj.populateToolbarForSources(source);
            obj.populateDetailsForSources(source);
            obj.updateStateOfControls();
        end

        function n = addSourceNode(obj, source)
            if isempty(source.parent)
                parent = obj.view.getSourcesFolderNode();
            else
                parent = obj.uuidToNode(source.parent.uuid);
            end

            n = obj.view.addSourceNode(parent, source.label, source);
            obj.uuidToNode(source.uuid) = n;

            children = source.sources;
            for i = 1:numel(children)
                obj.addSourceNode(children{i});
            end
        end
        
        function populateToolbarForSources(obj, sources)
            sourceSet = symphonyui.core.persistent.collections.SourceSet(sources);
            
            obj.view.setAddSourceToolVisible(sourceSet.size == 1);
            obj.view.setBeginEpochGroupToolVisible(false);
            obj.view.setEndEpochGroupToolVisible(false);
        end

        function populateDetailsForSources(obj, sources)
            sourceSet = symphonyui.core.persistent.collections.SourceSet(sources);

            obj.view.enableSourceLabel(sourceSet.size == 1);
            obj.view.setSourceLabel(sourceSet.label);
            obj.view.setCardSelection(obj.view.SOURCE_CARD);

            obj.populateAnnotationsForEntitySet(sourceSet);
            obj.detailedEntitySet = sourceSet;
        end

        function onViewSetSourceLabel(obj, ~, ~)
            sourceSet = obj.detailedEntitySet;

            try
                sourceSet.label = obj.view.getSourceLabel();
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end

            for i = 1:sourceSet.size
                source = sourceSet.get(i);

                snode = obj.uuidToNode(source.uuid);
                obj.view.setNodeName(snode, source.label);

                groups = source.epochGroups;
                for k = 1:numel(groups)
                    g = groups{k};
                    gnode = obj.uuidToNode(g.uuid);
                    obj.view.setNodeName(gnode, [g.label ' (' g.source.label ')']);
                end
            end
        end
        
        function populateToolbarForExperiments(obj, experiments)
            experimentSet = symphonyui.core.persistent.collections.ExperimentSet(experiments);
            
            obj.view.setAddSourceToolVisible(experimentSet.size == 1);
            obj.view.setBeginEpochGroupToolVisible(experimentSet.size == 1);
            obj.view.setEndEpochGroupToolVisible(false);
        end

        function populateDetailsForExperiments(obj, experiments)
            experimentSet = symphonyui.core.persistent.collections.ExperimentSet(experiments);

            obj.view.enableExperimentPurpose(experimentSet.size == 1);
            obj.view.setExperimentPurpose(experimentSet.purpose);
            obj.view.setExperimentStartTime(strtrim(datestr(experimentSet.startTime, 14)));
            obj.view.setExperimentEndTime(strtrim(datestr(experimentSet.endTime, 14)));
            obj.view.setCardSelection(obj.view.EXPERIMENT_CARD);

            obj.populateAnnotationsForEntitySet(experimentSet);
            obj.detailedEntitySet = experimentSet;
        end

        function onViewSetExperimentPurpose(obj, ~, ~)
            experimentSet = obj.detailedEntitySet;

            purpose = obj.view.getExperimentPurpose();
            try
                experimentSet.purpose = purpose;
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end

            for i = 1:experimentSet.size
                experiment = experimentSet.get(i);

                enode = obj.uuidToNode(experiment.uuid);
                if isempty(experiment.purpose)
                    name = datestr(experiment.startTime, 1);
                else
                    name = [experiment.purpose ' [' datestr(experiment.startTime, 1) ']'];
                end
                obj.view.setNodeName(enode, name);
            end
        end

        function onViewSelectedBeginEpochGroup(obj, ~, ~)
            initialParent = [];
            nodes = obj.view.getSelectedNodes();
            if numel(nodes) == 1 && obj.view.getNodeType(nodes(1)) == symphonyui.ui.views.EntityNodeType.EPOCH_GROUP
                initialParent = obj.view.getNodeEntity(nodes(1));
            end

            initialSource = [];
            currentGroup = obj.documentationService.getCurrentEpochGroup();
            if ~isempty(currentGroup)
                initialSource = currentGroup.source;
            end

            presenter = symphonyui.ui.presenters.BeginEpochGroupPresenter(obj.documentationService, initialParent, initialSource);
            presenter.goWaitStop();
        end

        function onServiceBeganEpochGroup(obj, ~, event)
            group = event.data;
            node = obj.addEpochGroupNode(group);

            obj.view.stopEditingProperties();
            obj.view.update();
            obj.view.setSelectedNodes(node);
            obj.view.setEpochGroupNodeCurrent(node);
            
            obj.populateToolbarForEpochGroups(group);
            obj.populateDetailsForEpochGroups(group);
            obj.updateStateOfControls();
        end

        function onViewSelectedEndEpochGroup(obj, ~, ~)
            nodes = obj.view.getSelectedNodes();
            assert(numel(nodes) == 1 && obj.view.getNodeType(nodes(1)) == symphonyui.ui.views.EntityNodeType.EPOCH_GROUP, ...
                'Expected a single epoch group to be selected');

            currentGroup = obj.documentationService.getCurrentEpochGroup();
            assert(~isempty(currentGroup), 'Expected current group not to be empty');

            group = obj.view.getNodeEntity(nodes(1));
            assert(any(cellfun(@(g)g == group, [{currentGroup} currentGroup.getAncestors()])), ...
                'Expected selected group to be the current epoch group or an ancestor');

            try
                while currentGroup ~= group.parent
                    obj.documentationService.endEpochGroup();
                    currentGroup = obj.documentationService.getCurrentEpochGroup();
                end
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end
        end

        function onServiceEndedEpochGroup(obj, ~, event)
            group = event.data;
            node = obj.uuidToNode(group.uuid);

            obj.view.stopEditingProperties();
            obj.view.update();
            obj.view.setSelectedNodes(node);
            obj.view.collapseNode(node);
            obj.view.setEpochGroupNodeNormal(node);
            
            obj.populateToolbarForNodes(node);
            obj.populateDetailsForEpochGroups(group);
            obj.updateStateOfControls();
        end

        function n = addEpochGroupNode(obj, group)
            if isempty(group.parent)
                parent = obj.view.getEpochGroupsFolderNode();
            else
                parent = obj.uuidToNode(group.parent.uuid);
            end

            n = obj.view.addEpochGroupNode(parent, [group.label ' (' group.source.label ')'], group);
            obj.uuidToNode(group.uuid) = n;

            blocks = group.epochBlocks;
            for i = 1:numel(blocks)
                obj.addEpochBlockNode(blocks{i});
            end

            children = group.epochGroups;
            for i = 1:numel(children)
                obj.addEpochGroupNode(children{i});
            end
        end

        function updateEpochGroupNode(obj, group)
            blocks = group.epochBlocks;
            for i = 1:numel(blocks)
                b = blocks{i};
                if ~obj.uuidToNode.isKey(b.uuid)
                    obj.addEpochBlockNode(b);
                else
                    obj.updateEpochBlockNode(b);
                end
            end

            children = group.epochGroups;
            for i = 1:numel(children)
                c = children{i};
                if ~obj.uuidToNode.isKey(c.uuid)
                    obj.addEpochGroupNode(c);
                else
                    obj.updateEpochGroupNode(c);
                end
            end
        end
        
        function populateToolbarForEpochGroups(obj, groups)
            groupSet = symphonyui.core.persistent.collections.EpochGroupSet(groups);
            
            obj.view.setAddSourceToolVisible(false);
            obj.view.setBeginEpochGroupToolVisible(groupSet.size == 1);
            obj.view.setEndEpochGroupToolVisible(groupSet.size == 1);
        end

        function populateDetailsForEpochGroups(obj, groups)
            groupSet = symphonyui.core.persistent.collections.EpochGroupSet(groups);
            sourceSet = symphonyui.core.persistent.collections.SourceSet(groupSet.source);

            obj.view.enableEpochGroupLabel(groupSet.size == 1);
            obj.view.setEpochGroupLabel(groupSet.label);
            obj.view.setEpochGroupStartTime(strtrim(datestr(groupSet.startTime, 14)));
            obj.view.setEpochGroupEndTime(strtrim(datestr(groupSet.endTime, 14)));
            obj.view.setEpochGroupSource(sourceSet.label);
            obj.view.setCardSelection(obj.view.EPOCH_GROUP_CARD);

            obj.populateAnnotationsForEntitySet(groupSet);
            obj.detailedEntitySet = groupSet;
        end

        function onViewSetEpochGroupLabel(obj, ~, ~)
            groupSet = obj.detailedEntitySet;

            label = obj.view.getEpochGroupLabel();
            try
                groupSet.label = label;
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end

            for i = 1:groupSet.size
                group = groupSet.get(i);

                gnode = obj.uuidToNode(group.uuid);
                obj.view.setNodeName(gnode, [group.label ' (' group.source.label ')']);
            end
        end

        function n = addEpochBlockNode(obj, block)
            parent = obj.uuidToNode(block.epochGroup.uuid);
            split = strsplit(block.protocolId, '.');
            n = obj.view.addEpochBlockNode(parent, [appbox.humanize(split{end}) ' [' datestr(block.startTime, 13) ']'], block);
            obj.uuidToNode(block.uuid) = n;

            epochs = block.epochs;
            for i = 1:numel(epochs)
                obj.addEpochNode(epochs{i});
            end
        end

        function updateEpochBlockNode(obj, block)
            epochs = block.epochs;
            for i = 1:numel(epochs)
                e = epochs{i};
                if ~obj.uuidToNode.isKey(e.uuid)
                    obj.addEpochNode(e);
                end
            end
        end
        
        function populateToolbarForEpochBlocks(obj, blocks)
            blockSet = symphonyui.core.persistent.collections.EpochBlockSet(blocks); %#ok<NASGU>
            
            obj.view.setAddSourceToolVisible(false);
            obj.view.setBeginEpochGroupToolVisible(false);
            obj.view.setEndEpochGroupToolVisible(false);
        end

        function populateDetailsForEpochBlocks(obj, blocks)
            blockSet = symphonyui.core.persistent.collections.EpochBlockSet(blocks);

            obj.view.setEpochBlockProtocolId(blockSet.protocolId);
            obj.view.setEpochBlockStartTime(strtrim(datestr(blockSet.startTime, 14)));
            obj.view.setEpochBlockEndTime(strtrim(datestr(blockSet.endTime, 14)));

            % Protocol parameters
            map = map2pmap(blockSet.protocolParameters);
            try
                properties = uiextras.jide.PropertyGridField.GenerateFrom(map);
            catch x
                properties = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
            end
            obj.view.setEpochBlockProtocolParameters(properties);

            obj.view.setCardSelection(obj.view.EPOCH_BLOCK_CARD);

            obj.populateAnnotationsForEntitySet(blockSet);
            obj.detailedEntitySet = blockSet;
        end

        function n = addEpochNode(obj, epoch)
            parent = obj.uuidToNode(epoch.epochBlock.uuid);
            n = obj.view.addEpochNode(parent, datestr(epoch.startTime, 'HH:MM:SS:FFF'), epoch);
            obj.uuidToNode(epoch.uuid) = n;
        end
        
        function populateToolbarForEpochs(obj, epochs)
            epochSet = symphonyui.core.persistent.collections.EpochSet(epochs); %#ok<NASGU>
            
            obj.view.setAddSourceToolVisible(false);
            obj.view.setBeginEpochGroupToolVisible(false);
            obj.view.setEndEpochGroupToolVisible(false);
        end

        function populateDetailsForEpochs(obj, epochs)
            epochSet = symphonyui.core.persistent.collections.EpochSet(epochs);

            responseMap = epochSet.getResponseMap();
            stimulusMap = epochSet.getStimulusMap();

            names = [strcat(responseMap.keys, ' response'), strcat(stimulusMap.keys, ' stimulus')];
            values = [responseMap.values, stimulusMap.values];
            if isempty(names)
                names = {'(None)'};
                values = {[]};
            end
            obj.view.setEpochSignalList(names, values);

            obj.populateDetailsForSignals(obj.view.getSelectedEpochSignal());

            % Protocol parameters
            map = map2pmap(epochSet.protocolParameters);
            try
                fields = uiextras.jide.PropertyGridField.GenerateFrom(map);
            catch x
                fields = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
            end
            obj.view.setEpochProtocolParameters(fields);

            obj.view.setCardSelection(obj.view.EPOCH_CARD);

            obj.populateAnnotationsForEntitySet(epochSet);
            obj.detailedEntitySet = epochSet;
        end

        function onViewSelectedEpochSignal(obj, ~, ~)
            obj.populateDetailsForSignals(obj.view.getSelectedEpochSignal());
        end

        function populateDetailsForSignals(obj, signals)
            obj.view.clearEpochDataAxes();

            ylabels = cell(1, numel(signals));
            llabels = cell(1, numel(signals));
            colorOrder = get(groot, 'defaultAxesColorOrder');
            for i = 1:numel(signals)
                s = signals{i};
                [ydata, yunits] = s.getData();
                rate = s.getSampleRate();
                xdata = (1:numel(ydata))/rate;
                color = colorOrder(mod(i - 1, size(colorOrder, 1)) + 1, :);
                ylabels{i} = [s.device.name ' (' yunits ')'];
                llabels{i} = datestr(s.epoch.startTime, 'HH:MM:SS:FFF');
                obj.view.addEpochDataLine(xdata, ydata, color);
            end

            obj.view.setEpochDataAxesLabels('Time (s)', strjoin(unique(ylabels), ', '));

            if numel(llabels) > 1
                obj.view.addEpochDataLegend(llabels);
            end
        end
        
        function populateToolbarForEmpty(obj)
            obj.view.setAddSourceToolVisible(false);
            obj.view.setBeginEpochGroupToolVisible(false);
            obj.view.setEndEpochGroupToolVisible(false);
        end

        function populateDetailsForEmpty(obj, text)
            emptySet = symphonyui.core.persistent.collections.EntitySet();

            obj.view.setEmptyText(text);
            obj.view.setCardSelection(obj.view.EMPTY_CARD);

            obj.populateAnnotationsForEntitySet(emptySet);
            obj.detailedEntitySet = emptySet;
        end

        function onViewSelectedNodes(obj, ~, ~)
            obj.view.stopEditingProperties();
            obj.view.update();
            
            nodes = obj.view.getSelectedNodes();
            obj.populateToolbarForNodes(nodes);
            obj.populateDetailsForNodes(nodes);
        end
        
        function populateToolbarForNodes(obj, nodes)
            import symphonyui.ui.views.EntityNodeType;
            
            entities = cell(1, numel(nodes));
            types = symphonyui.ui.views.EntityNodeType.empty(0, numel(nodes));
            for i = 1:numel(nodes)
                entities{i} = obj.view.getNodeEntity(nodes(i));
                types(i) = obj.view.getNodeType(nodes(i));
            end
            
            if isempty(types) || numel(types) > 1
                obj.populateToolbarForEmpty();
                return;
            end
            type = types(1);
            
            switch type
                case EntityNodeType.SOURCE
                    obj.populateToolbarForSources(entities);
                case EntityNodeType.EXPERIMENT
                    obj.populateToolbarForExperiments(entities);
                case EntityNodeType.EPOCH_GROUP
                    obj.populateToolbarForEpochGroups(entities);
                case EntityNodeType.EPOCH_BLOCK
                    obj.populateToolbarForEpochBlocks(entities);
                case EntityNodeType.EPOCH
                    obj.populateToolbarForEpochs(entities);
                otherwise
                    obj.populateToolbarForEmpty();
            end
        end

        function populateDetailsForNodes(obj, nodes)
            import symphonyui.ui.views.EntityNodeType;

            entities = cell(1, numel(nodes));
            types = symphonyui.ui.views.EntityNodeType.empty(0, numel(nodes));
            for i = 1:numel(nodes)
                entities{i} = obj.view.getNodeEntity(nodes(i));
                types(i) = obj.view.getNodeType(nodes(i));
            end

            types = unique(types);
            if isempty(types) || numel(types) > 1
                obj.populateDetailsForEmpty(strjoin(arrayfun(@(t)char(t), types, 'UniformOutput', false), ', '));
                return;
            end
            type = types(1);

            switch type
                case EntityNodeType.SOURCE
                    obj.populateDetailsForSources(entities);
                case EntityNodeType.EXPERIMENT
                    obj.populateDetailsForExperiments(entities);
                case EntityNodeType.EPOCH_GROUP
                    obj.populateDetailsForEpochGroups(entities);
                case EntityNodeType.EPOCH_BLOCK
                    obj.populateDetailsForEpochBlocks(entities);
                case EntityNodeType.EPOCH
                    obj.populateDetailsForEpochs(entities);
                otherwise
                    obj.populateDetailsForEmpty(strjoin(arrayfun(@(t)char(t), type, 'UniformOutput', false), ', '));
            end
        end

        function populateAnnotationsForEntitySet(obj, entitySet)
            obj.populatePropertiesForEntitySet(entitySet);
            obj.populateKeywordsForEntitySet(entitySet);
            obj.populateNotesForEntitySet(entitySet);
        end

        function populatePropertiesForEntitySet(obj, entitySet)
            try
                fields = symphonyui.ui.util.desc2field(entitySet.getPropertyDescriptors());
            catch x
                fields = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
            end
            obj.view.setProperties(fields);
        end

        function updatePropertiesForEntitySet(obj, entitySet)
            try
                fields = symphonyui.ui.util.desc2field(entitySet.getPropertyDescriptors());
            catch x
                fields = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
            end
            obj.view.updateProperties(fields);
        end

        function onViewSetProperty(obj, ~, event)
            p = event.data.Property;
            try
                obj.detailedEntitySet.setProperty(p.Name, p.Value);
            catch x
                obj.view.showError(x.message);
                return;
            end
            obj.updatePropertiesForEntitySet(obj.detailedEntitySet);
        end

        function onViewSelectedAddProperty(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddPropertyPresenter(obj.detailedEntitySet);
            presenter.goWaitStop();

            if ~isempty(presenter.result)
                obj.populatePropertiesForEntitySet(obj.detailedEntitySet);
            end
        end

        function onViewSelectedRemoveProperty(obj, ~, ~)
            key = obj.view.getSelectedProperty();
            if isempty(key)
                return;
            end
            try
                tf = obj.detailedEntitySet.removeProperty(key);
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end

            if tf
                obj.populatePropertiesForEntitySet(obj.detailedEntitySet);
            end
        end

        function populateKeywordsForEntitySet(obj, entitySet)
            obj.view.setKeywords(entitySet.keywords);
        end

        function onViewSelectedAddKeyword(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddKeywordPresenter(obj.detailedEntitySet);
            presenter.goWaitStop();

            if ~isempty(presenter.result)
                keyword = presenter.result;
                obj.view.addKeyword(keyword);
            end
        end

        function onViewSelectedRemoveKeyword(obj, ~, ~)
            keyword = obj.view.getSelectedKeyword();
            if isempty(keyword)
                return;
            end
            try
                obj.detailedEntitySet.removeKeyword(keyword);
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end

            obj.view.removeKeyword(keyword);
        end

        function populateNotesForEntitySet(obj, entitySet)
            notes = entitySet.notes;

            data = cell(1, numel(notes));
            for i = 1:numel(notes)
                data{i} = {strtrim(datestr(notes{i}.time, 14)), notes{i}.text};
            end
            obj.view.setNotes(data);
        end

        function onViewSelectedAddNote(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddNotePresenter(obj.detailedEntitySet);
            presenter.goWaitStop();

            if ~isempty(presenter.result)
                note = presenter.result;
                obj.view.addNote(strtrim(datestr(note.time, 14)), note.text);
            end
        end

        function onViewSelectedSendEntityToWorkspace(obj, ~, ~)
            nodes = obj.view.getSelectedNodes();
            assert(numel(nodes) == 1, 'Expected a single entity');

            entity = obj.view.getNodeEntity(nodes(1));
            try
                obj.documentationService.sendEntityToWorkspace(entity);
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end
        end

        function onViewSelectedDeleteEntity(obj, ~, ~)
            nodes = obj.view.getSelectedNodes();
            assert(numel(nodes) == 1, 'Expected a single entity');

            name = obj.view.getNodeName(nodes(1));
            result = obj.view.showMessage( ...
                ['Are you sure you want to delete ''' name '''?'], ...
                'Delete Entity', ...
                'Cancel', 'Delete');
            if ~strcmp(result, 'Delete')
                return;
            end

            entity = obj.view.getNodeEntity(nodes(1));
            try
                obj.documentationService.deleteEntity(entity);
            catch x
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
                return;
            end
        end

        function onServiceDeletedEntity(obj, ~, event)
            uuid = event.data;
            node = obj.uuidToNode(uuid);

            obj.view.removeNode(node);
            obj.uuidToNode.remove(uuid);
            
            nodes = obj.view.getSelectedNodes();
            obj.populateToolbarForNodes(nodes);
            obj.populateDetailsForNodes(nodes);
            obj.updateStateOfControls();
        end

        function onViewSelectedOpenAxesInNewWindow(obj, ~, ~)
            obj.view.openEpochDataAxesInNewWindow();
        end

        function onServiceChangedControllerState(obj, ~, ~)
            obj.updateStateOfControls();

            state = obj.acquisitionService.getControllerState();
            if state.isPaused() || state.isStopped()
                group = obj.documentationService.getCurrentEpochGroup();
                if isempty(group)
                    return;
                end
                obj.updateEpochGroupNode(group);
            end
        end

        function updateStateOfControls(obj)
            hasSource = ~isempty(obj.documentationService.getExperiment().sources);
            controllerState = obj.acquisitionService.getControllerState();
            isStopped = controllerState.isStopped();

            enableBeginEpochGroup = hasSource && isStopped;
            
            obj.view.enableBeginEpochGroupTool(enableBeginEpochGroup);
            obj.view.enableBeginEpochGroupMenu(obj.view.getExperimentNode(), enableBeginEpochGroup);
            obj.view.enableBeginEpochGroupMenu(obj.view.getEpochGroupsFolderNode(), enableBeginEpochGroup);
        end

        function loadSettings(obj)
            if ~isempty(obj.settings.viewPosition)
                obj.view.position = obj.settings.viewPosition;
            end
        end

        function saveSettings(obj)
            obj.settings.viewPosition = obj.view.position;
            obj.settings.save();
        end

    end

end

function map = map2pmap(map)
    keys = map.keys;
    for i = 1:numel(keys)
        k = keys{i};
        v = map(k);
        if iscell(v)
            for j = 1:numel(v)
                if ismatrix(v{j})
                    v{j} = mat2str(v{j});
                elseif isnumeric(v{j})
                    v{j} = num2str(v{j});
                end
            end
            if ~iscellstr(v)
                v = '...';
            end
            map(k) = v;
        end
    end
end
