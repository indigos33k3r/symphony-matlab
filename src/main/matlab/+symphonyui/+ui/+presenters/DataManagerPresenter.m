classdef DataManagerPresenter < symphonyui.ui.Presenter

    properties (Access = private)
        documentationService
        uuidToNode
        detailedEntitySet
    end

    methods

        function obj = DataManagerPresenter(documentationService, app, view)
            if nargin < 3
                view = symphonyui.ui.views.DataManagerView();
            end
            obj = obj@symphonyui.ui.Presenter(app, view);

            obj.documentationService = documentationService;
            obj.detailedEntitySet = symphonyui.core.collections.EntitySet();
            obj.uuidToNode = containers.Map();
        end
        
        function updateCurrentEpochGroupBlocks(obj)
            group = obj.documentationService.getCurrentEpochGroup();
            if isempty(group)
                return;
            end
            blocks = group.epochBlocks;
            for i = 1:numel(blocks)
                b = blocks{i};
                if ~obj.uuidToNode.isKey(b.uuid)
                    obj.addEpochBlockNode(b);
                end
            end
        end

    end

    methods (Access = protected)

        function onGoing(obj)
            obj.populateEntityTree();
            obj.updateStateOfControls();
        end

        function onBind(obj)
            v = obj.view;
            obj.addListener(v, 'AddSource', @obj.onViewSelectedAddSource);
            obj.addListener(v, 'BeginEpochGroup', @obj.onViewSelectedBeginEpochGroup);
            obj.addListener(v, 'EndEpochGroup', @obj.onViewSelectedEndEpochGroup);
            obj.addListener(v, 'SelectedNodes', @obj.onViewSelectedNodes);
            obj.addListener(v, 'SetSourceLabel', @obj.onViewSetSourceLabel);
            obj.addListener(v, 'SetExperimentPurpose', @obj.onViewSetExperimentPurpose);
            obj.addListener(v, 'SetEpochGroupLabel', @obj.onViewSetEpochGroupLabel);
            obj.addListener(v, 'SelectedPropertyTemplate', @obj.onViewSelectedPropertyTemplate);
            obj.addListener(v, 'SetProperty', @obj.onViewSetProperty);
            obj.addListener(v, 'AddProperty', @obj.onViewSelectedAddProperty);
            obj.addListener(v, 'RemoveProperty', @obj.onViewSelectedRemoveProperty);
            obj.addListener(v, 'AddKeyword', @obj.onViewSelectedAddKeyword);
            obj.addListener(v, 'RemoveKeyword', @obj.onViewSelectedRemoveKeyword);
            obj.addListener(v, 'AddNote', @obj.onViewSelectedAddNote);
            obj.addListener(v, 'SendEntityToWorkspace', @obj.onViewSelectedSendEntityToWorkspace);
            obj.addListener(v, 'DeleteEntity', @obj.onViewSelectedDeleteEntity);
            obj.addListener(v, 'Refresh', @obj.onViewSelectedRefresh);
            obj.addListener(v, 'OpenAxesInNewWindow', @obj.onViewSelectedOpenAxesInNewWindow);

            d = obj.documentationService;
            obj.addListener(d, 'AddedDevice', @obj.onServiceAddedDevice);
            obj.addListener(d, 'AddedSource', @obj.onServiceAddedSource);
            obj.addListener(d, 'BeganEpochGroup', @obj.onServiceBeganEpochGroup);
            obj.addListener(d, 'EndedEpochGroup', @obj.onServiceEndedEpochGroup);
            obj.addListener(d, 'DeletedEntity', @obj.onServiceDeletedEntity);
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

            devices = experiment.devices;
            for i = 1:numel(devices)
                obj.addDeviceNode(devices{i});
            end
            obj.view.expandNode(obj.view.getDevicesFolderNode());

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
            obj.populateDetailsWithExperiments(experiment);
        end

        function onServiceAddedDevice(obj, ~, event)
            device = event.data;
            node = obj.addDeviceNode(device);

            obj.view.setSelectedNodes(node);

            obj.populateDetailsWithDevices(device);
            obj.updateStateOfControls();
        end

        function n = addDeviceNode(obj, device)
            n = obj.view.addDeviceNode(obj.view.getDevicesFolderNode(), device.name, device);
            obj.uuidToNode(device.uuid) = n;
        end

        function populateDetailsWithDevices(obj, devices)
            deviceSet = symphonyui.core.collections.DeviceSet(devices);

            obj.view.setDeviceName(deviceSet.name);
            obj.view.setDeviceManufacturer(deviceSet.manufacturer);
            obj.view.setCardSelection(obj.view.DEVICE_CARD);

            obj.populateAnnotationsWithEntitySet(deviceSet);
            obj.detailedEntitySet = deviceSet;
        end

        function onViewSelectedAddSource(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddSourcePresenter(obj.documentationService, obj.app);
            presenter.goWaitStop();
        end

        function onServiceAddedSource(obj, ~, event)
            source = event.data;
            node = obj.addSourceNode(source);

            obj.view.setSelectedNodes(node);

            obj.populateDetailsWithSources(source);
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

        function populateDetailsWithSources(obj, sources)
            sourceSet = symphonyui.core.collections.SourceSet(sources);

            obj.view.enableSourceLabel(sourceSet.size == 1);
            obj.view.setSourceLabel(sourceSet.label);
            obj.view.setCardSelection(obj.view.SOURCE_CARD);

            obj.populateAnnotationsWithEntitySet(sourceSet);
            obj.detailedEntitySet = sourceSet;
        end

        function onViewSetSourceLabel(obj, ~, ~)
            sourceSet = obj.detailedEntitySet;

            try
                sourceSet.label = obj.view.getSourceLabel();
            catch x
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

        function populateDetailsWithExperiments(obj, experiments)
            experimentSet = symphonyui.core.collections.ExperimentSet(experiments);

            obj.view.enableExperimentPurpose(experimentSet.size == 1);
            obj.view.setExperimentPurpose(experimentSet.purpose);
            obj.view.setExperimentStartTime(strtrim(datestr(experimentSet.startTime, 14)));
            obj.view.setExperimentEndTime(strtrim(datestr(experimentSet.endTime, 14)));
            obj.view.setCardSelection(obj.view.EXPERIMENT_CARD);

            obj.populateAnnotationsWithEntitySet(experimentSet);
            obj.detailedEntitySet = experimentSet;
        end

        function onViewSetExperimentPurpose(obj, ~, ~)
            experimentSet = obj.detailedEntitySet;

            purpose = obj.view.getExperimentPurpose();
            try
                experimentSet.purpose = purpose;
            catch x
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
            presenter = symphonyui.ui.presenters.BeginEpochGroupPresenter(obj.documentationService, obj.app);
            presenter.goWaitStop();
        end

        function onServiceBeganEpochGroup(obj, ~, event)
            group = event.data;
            node = obj.addEpochGroupNode(group);

            obj.view.setSelectedNodes(node);
            obj.view.setEpochGroupNodeCurrent(node);

            obj.populateDetailsWithEpochGroups(group);
            obj.updateStateOfControls();
        end

        function onViewSelectedEndEpochGroup(obj, ~, ~)
            try
                obj.documentationService.endEpochGroup();
            catch x
                obj.view.showError(x.message);
                return;
            end
        end

        function onServiceEndedEpochGroup(obj, ~, event)
            group = event.data;
            node = obj.uuidToNode(group.uuid);

            obj.view.setSelectedNodes(node);
            obj.view.collapseNode(node);
            obj.view.setEpochGroupNodeNormal(node);

            obj.populateDetailsWithEpochGroups(group);
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

        function populateDetailsWithEpochGroups(obj, groups)
            groupSet = symphonyui.core.collections.EpochGroupSet(groups);
            sourceSet = symphonyui.core.collections.SourceSet(groupSet.sources);

            obj.view.enableEpochGroupLabel(groupSet.size == 1);
            obj.view.setEpochGroupLabel(groupSet.label);
            obj.view.setEpochGroupStartTime(strtrim(datestr(groupSet.startTime, 14)));
            obj.view.setEpochGroupEndTime(strtrim(datestr(groupSet.endTime, 14)));
            obj.view.setEpochGroupSource(sourceSet.label);
            obj.view.setCardSelection(obj.view.EPOCH_GROUP_CARD);

            obj.populateAnnotationsWithEntitySet(groupSet);
            obj.detailedEntitySet = groupSet;
        end

        function onViewSetEpochGroupLabel(obj, ~, ~)
            groupSet = obj.detailedEntitySet;

            label = obj.view.getEpochGroupLabel();
            try
                groupSet.label = label;
            catch x
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
            n = obj.view.addEpochBlockNode(parent, [split{end} ' [' datestr(block.startTime, 13) ']'], block);
            obj.uuidToNode(block.uuid) = n;

            epochs = block.epochs;
            for i = 1:numel(epochs)
                obj.addEpochNode(epochs{i});
            end
        end

        function populateDetailsWithEpochBlocks(obj, blocks)
            blockSet = symphonyui.core.collections.EpochBlockSet(blocks);

            obj.view.setEpochBlockProtocolId(blockSet.protocolId);
            obj.view.setEpochBlockStartTime(strtrim(datestr(blockSet.startTime, 14)));
            obj.view.setEpochBlockEndTime(strtrim(datestr(blockSet.endTime, 14)));
            obj.view.setCardSelection(obj.view.EPOCH_BLOCK_CARD);

            obj.populateAnnotationsWithEntitySet(blockSet);
            obj.detailedEntitySet = blockSet;
        end

        function n = addEpochNode(obj, epoch)
            parent = obj.uuidToNode(epoch.epochBlock.uuid);
            n = obj.view.addEpochNode(parent, datestr(epoch.startTime, 'HH:MM:SS:FFF'), epoch);
            obj.uuidToNode(epoch.uuid) = n;
        end

        function populateDetailsWithEpochs(obj, epochs)
            epochSet = symphonyui.core.collections.EpochSet(epochs);

            % Plot
            obj.view.clearEpochDataAxes();
            obj.view.setEpochDataAxesLabels('Time (s)', 'Data');
            responseMap = epochSet.responseMap;
            colorOrder = get(groot, 'defaultAxesColorOrder');
            devices = responseMap.keys;
            groups = [];
            for i = 1:numel(devices)
                color = colorOrder(mod(i, size(colorOrder, 1)), :);
                responses = responseMap(devices{i});
                for k = 1:numel(responses)
                    r = responses{k};
                    ydata = r.getData();
                    rate = r.getSampleRate();
                    xdata = (1:numel(ydata))/rate;

                    obj.view.addEpochDataLine(xdata, ydata, color);
                    groups = [groups i]; %#ok<AGROW>
                end
            end
            obj.view.clearEpochDataLegend();
            if ~isempty(devices)
                obj.view.setEpochDataLegend(devices, groups);
            end

            % Protocol parameters
            map = map2pmap(epochSet.protocolParameters);
            try
                properties = uiextras.jide.PropertyGridField.GenerateFrom(map);
            catch x
                properties = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
            end
            obj.view.setEpochProtocolParameters(properties);

            obj.view.setCardSelection(obj.view.EPOCH_CARD);

            obj.populateAnnotationsWithEntitySet(epochSet);
            obj.detailedEntitySet = epochSet;
        end

        function populateDetailsWithEmpty(obj, text)
            emptySet = symphonyui.core.collections.EntitySet();

            obj.view.setEmptyText(text);
            obj.view.setCardSelection(obj.view.EMPTY_CARD);

            obj.populateAnnotationsWithEntitySet(emptySet);
            obj.detailedEntitySet = emptySet;
        end

        function onViewSelectedNodes(obj, ~, ~)
            obj.view.update();
            obj.populateDetailsWithNodes(obj.view.getSelectedNodes());
        end

        function populateDetailsWithNodes(obj, nodes)
            import symphonyui.ui.views.EntityNodeType;

            entities = cell(1, numel(nodes));
            types = symphonyui.ui.views.EntityNodeType.empty(0, numel(nodes));
            for i = 1:numel(nodes)
                entities{i} = obj.view.getNodeEntity(nodes(i));
                types(i) = obj.view.getNodeType(nodes(i));
            end

            types = unique(types);
            if isempty(types) || numel(types) > 1
                obj.populateDetailsWithEmpty(strjoin(arrayfun(@(t)char(t), types, 'UniformOutput', false), ', '));
                return;
            end

            switch types
                case EntityNodeType.DEVICE
                    obj.populateDetailsWithDevices(entities);
                case EntityNodeType.SOURCE
                    obj.populateDetailsWithSources(entities);
                case EntityNodeType.EXPERIMENT
                    obj.populateDetailsWithExperiments(entities);
                case EntityNodeType.EPOCH_GROUP
                    obj.populateDetailsWithEpochGroups(entities);
                case EntityNodeType.EPOCH_BLOCK
                    obj.populateDetailsWithEpochBlocks(entities);
                case EntityNodeType.EPOCH
                    obj.populateDetailsWithEpochs(entities);
                otherwise
                    obj.populateDetailsWithEmpty(strjoin(arrayfun(@(t)char(t), types, 'UniformOutput', false), ', '));
            end
        end

        function populateAnnotationsWithEntitySet(obj, entitySet)
            obj.populatePropertyTemplateList();
            obj.populatePropertiesWithEntitySet(entitySet);
            obj.populateKeywordsWithEntitySet(entitySet);
            obj.populateNotesWithEntitySet(entitySet);
        end

        function populatePropertyTemplateList(obj)
            obj.view.setPropertyTemplateList({'Select template...'}, {'Select template...'});
        end

        function onViewSelectedPropertyTemplate(obj, ~, ~)
            disp(obj.view.getSelectedPropertyTemplate());
        end

        function populatePropertiesWithEntitySet(obj, entitySet, update)
            if nargin < 3
                update = false;
            end
            try
                fields = symphonyui.ui.util.desc2field(entitySet.getPropertyDescriptors());
            catch x
                fields = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.log.debug(x.message, x);
                obj.view.showError(x.message);
            end
            if update
                obj.view.updateProperties(fields);
            else
                obj.view.setProperties(fields);
            end

            if entitySet.size == 1
                obj.view.setPropertiesEditorStyle('normal');
            else
                obj.view.setPropertiesEditorStyle('readonly');
            end
        end

        function onViewSetProperty(obj, ~, event)
            p = event.data.Property;
            try
                obj.detailedEntitySet.addProperty(p.Name, p.Value);
            catch x
                obj.view.showError(x.message);
                return;
            end

            obj.populatePropertiesWithEntitySet(obj.detailedEntitySet, true);
        end

        function onViewSelectedAddProperty(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddPropertyPresenter(obj.detailedEntitySet, obj.app);
            presenter.goWaitStop();

            if ~isempty(presenter.result)
                obj.populatePropertiesWithEntitySet(obj.detailedEntitySet);
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
                obj.view.showError(x.message);
                return;
            end

            if tf
                obj.populatePropertiesWithEntitySet(obj.detailedEntitySet);
            end
        end

        function populateKeywordsWithEntitySet(obj, entitySet)
            obj.view.setKeywords(entitySet.keywords);
        end

        function onViewSelectedAddKeyword(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddKeywordPresenter(obj.detailedEntitySet, obj.app);
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
                obj.view.showError(x.message);
                return;
            end

            obj.view.removeKeyword(keyword);
        end

        function populateNotesWithEntitySet(obj, entitySet)
            notes = entitySet.notes;

            data = cell(1, numel(notes));
            for i = 1:numel(notes)
                data{i} = {strtrim(datestr(notes{i}.time, 14)), notes{i}.text};
            end
            obj.view.setNotes(data);
        end

        function onViewSelectedAddNote(obj, ~, ~)
            presenter = symphonyui.ui.presenters.AddNotePresenter(obj.detailedEntitySet, obj.app);
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
                obj.view.showError(x.message);
                return;
            end
        end

        function onViewSelectedDeleteEntity(obj, ~, ~)
            nodes = obj.view.getSelectedNodes();
            assert(numel(nodes) == 1, 'Expected a single entity');

            entity = obj.view.getNodeEntity(nodes(1));
            try
                obj.documentationService.deleteEntity(entity);
            catch x
                obj.view.showError(x.message);
                return;
            end
        end

        function onServiceDeletedEntity(obj, ~, event)
            uuid = event.data;
            node = obj.uuidToNode(uuid);

            obj.view.removeNode(node);
            obj.uuidToNode.remove(uuid);

            obj.populateDetailsWithNodes(obj.view.getSelectedNodes());
            obj.updateStateOfControls();
        end

        function onViewSelectedRefresh(obj, ~, ~)
            % TODO: Implement
            obj.view.showError('Not implemented yet');
        end

        function onViewSelectedOpenAxesInNewWindow(obj, ~, ~)
            obj.view.openEpochDataAxesInNewWindow();
        end

        function updateStateOfControls(obj)
            hasOpenFile = obj.documentationService.hasOpenFile();
            hasSource = hasOpenFile && ~isempty(obj.documentationService.getExperiment().sources);
            hasEpochGroup = hasOpenFile && ~isempty(obj.documentationService.getCurrentEpochGroup());

            obj.view.enableBeginEpochGroup(hasSource);
            obj.view.enableEndEpochGroup(hasEpochGroup);
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
