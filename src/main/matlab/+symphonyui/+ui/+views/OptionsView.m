classdef OptionsView < appbox.View

    events
        SelectedNode
        BrowseStartupFile
        BrowseFileDefaultLocation
        BrowseLoggingConfigurationFile
        BrowseLoggingLogDirectory
        AddSearchPath
        RemoveSearchPath
        ShowExcludeHelp
        Save
        Default
        Cancel
    end

    properties (Access = private)
        masterList
        detailCardPanel
        generalCard
        fileCard
        searchPathCard
        loggingCard
        saveButton
        defaultButton
        cancelButton
    end

    methods

        function createUi(obj)
            import appbox.*;

            set(obj.figureHandle, ...
                'Name', 'Options', ...
                'Position', screenCenter(550, 300));

            mainLayout = uix.VBox( ...
                'Parent', obj.figureHandle, ...
                'Padding', 11, ...
                'Spacing', 11);

            optionsLayout = uix.HBox( ...
                'Parent', mainLayout, ...
                'Spacing', 7);

            masterLayout = uix.VBox( ...
                'Parent', optionsLayout);

            obj.masterList = uicontrol( ...
                'Parent', masterLayout, ...
                'Style', 'list', ...
                'String', {'General', 'File', 'Search Path', 'Logging'}, ...
                'Callback', @(h,d)notify(obj, 'SelectedNode'));

            detailLayout = uix.VBox( ...
                'Parent', optionsLayout, ...
                'Spacing', 7);

            obj.detailCardPanel = uix.CardPanel( ...
                'Parent', detailLayout);

            % General card.
            generalLayout = uix.VBox( ...
                'Parent', obj.detailCardPanel, ...
                'Spacing', 7);
            
            generalGrid = uix.Grid( ...
                'Parent', generalLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', generalGrid, ...
                'String', 'Startup file:');
            obj.generalCard.startupFileField = uicontrol( ...
                'Parent', generalGrid, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.generalCard.browseStartupFileButton = uicontrol( ...
                'Parent', generalGrid, ...
                'Style', 'pushbutton', ...
                'String', '...', ...
                'Callback', @(h,d)notify(obj, 'BrowseStartupFile'));
            set(generalGrid, ...
                'Widths', [65 -1 23], ...
                'Heights', 23);
            
            obj.generalCard.warnOnViewOnlyWithOpenFileCheckBox = uicontrol( ...
                'Parent', generalLayout, ...
                'Style', 'checkbox', ...
                'String', 'Show warning before running "View Only" with an open file');
            
            set(generalLayout, 'Heights', [layoutHeight(generalGrid) 23]);
            
            % File card.
            fileGrid = uix.Grid( ...
                'Parent', obj.detailCardPanel, ...
                'Spacing', 7);
            Label( ...
                'Parent', fileGrid, ...
                'String', 'Default name:');
            Label( ...
                'Parent', fileGrid, ...
                'String', 'Default location:');
            obj.fileCard.defaultNameField = uicontrol( ...
                'Parent', fileGrid, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.fileCard.defaultLocationField = uicontrol( ...
                'Parent', fileGrid, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            uix.Empty('Parent', fileGrid);
            obj.generalCard.browseDefaultLocationButton = uicontrol( ...
                'Parent', fileGrid, ...
                'Style', 'pushbutton', ...
                'String', '...', ...
                'Callback', @(h,d)notify(obj, 'BrowseFileDefaultLocation'));
            set(fileGrid, ...
                'Widths', [90 -1 23], ...
                'Heights', [23 23]);

            % Search path card.
            searchPathLayout = uix.VBox( ...
                'Parent', obj.detailCardPanel, ...
                'Spacing', 7);
            searchPathListLayout = uix.HBox( ...
                'Parent', searchPathLayout, ...
                'Spacing', 7);
            obj.searchPathCard.list = ListBox( ...
                'Parent', searchPathListLayout, ...
                'Style', 'list', ...
                'String', {});
            searchPathMenu = uicontextmenu('Parent', obj.figureHandle);
            uimenu( ...
                'Parent', searchPathMenu, ...
                'Label', 'Add...', ...
                'Callback', @(h,d)notify(obj, 'AddSearchPath'));
            uimenu( ...
                'Parent', searchPathMenu, ...
                'Label', 'Remove', ...
                'Callback', @(h,d)notify(obj, 'RemoveSearchPath'));
            set(obj.searchPathCard.list, 'UIContextMenu', searchPathMenu);
            searchPathControlsLayout = uix.VBox( ...
                'Parent', searchPathListLayout, ...
                'Spacing', 7);
            obj.searchPathCard.addButton = uicontrol( ...
                'Parent', searchPathControlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Add...', ...
                'Interruptible', 'off', ...
                'Callback', @(h,d)notify(obj, 'AddSearchPath'));
            obj.searchPathCard.removeButton = uicontrol( ...
                'Parent', searchPathControlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Remove', ...
                'Interruptible', 'off', ...
                'Callback', @(h,d)notify(obj, 'RemoveSearchPath'));
            uix.Empty('Parent', searchPathControlsLayout);
            set(searchPathControlsLayout, 'Heights', [23 23 -1]);
            set(searchPathListLayout, 'Widths', [-1 75]);
            searchPathExcludeLayout = uix.HBox( ...
                'Parent', searchPathLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', searchPathExcludeLayout, ...
                'String', 'Exclude:');
            obj.searchPathCard.excludeField = uicontrol( ...
                'Parent', searchPathExcludeLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.searchPathCard.excludeHelpButton = uicontrol( ...
                'Parent', searchPathExcludeLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Help', ...
                'Callback', @(h,d)notify(obj, 'ShowExcludeHelp'));
            set(searchPathExcludeLayout, 'Widths', [47 -1 75]);
            set(searchPathLayout, 'Heights', [-1 23]);

            % Logging card.
            loggingGrid = uix.Grid( ...
                'Parent', obj.detailCardPanel, ...
                'Spacing', 7);
            Label( ...
                'Parent', loggingGrid, ...
                'String', 'Configuration file:');
            Label( ...
                'Parent', loggingGrid, ...
                'String', 'Log directory:');
            obj.loggingCard.configurationFileField = uicontrol( ...
                'Parent', loggingGrid, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.loggingCard.logDirectoryField = uicontrol( ...
                'Parent', loggingGrid, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.loggingCard.BrowseLoggingConfigurationFileButton = uicontrol( ...
                'Parent', loggingGrid, ...
                'Style', 'pushbutton', ...
                'String', '...', ...
                'Callback', @(h,d)notify(obj, 'BrowseLoggingConfigurationFile'));
            obj.loggingCard.BrowseLoggingLogDirectoryButton = uicontrol( ...
                'Parent', loggingGrid, ...
                'Style', 'pushbutton', ...
                'String', '...', ...
                'Callback', @(h,d)notify(obj, 'BrowseLoggingLogDirectory'));
            set(loggingGrid, ...
                'Widths', [100 -1 23], ...
                'Heights', [23 23]);

            set(obj.detailCardPanel, 'Selection', 1);

            Separator('Parent', detailLayout);

            set(detailLayout, 'Heights', [-1 1]);

            set(optionsLayout, 'Widths', [120 -1]);

            % Save/Default/Cancel controls.
            controlsLayout = uiextras.HBox( ...
                'Parent', mainLayout, ...
                'Spacing', 7);
            uiextras.Empty('Parent', controlsLayout);
            obj.saveButton = uicontrol( ...
                'Parent', controlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Save', ...
                'Interruptible', 'off', ...
                'Callback', @(h,d)notify(obj, 'Save'));
            obj.defaultButton = uicontrol( ...
                'Parent', controlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Default', ...
                'Interruptible', 'off', ...
                'Callback', @(h,d)notify(obj, 'Default'));
            obj.cancelButton = uicontrol( ...
                'Parent', controlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Cancel', ...
                'Interruptible', 'off', ...
                'Callback', @(h,d)notify(obj, 'Cancel'));
            set(controlsLayout, 'Sizes', [-1 75 75 75]);

            set(mainLayout, 'Heights', [-1 23]);

            % Set OK button to appear as the default button.
            try %#ok<TRYNC>
                h = handle(obj.figureHandle);
                h.setDefaultButton(obj.saveButton);
            end
        end

        function i = getSelectedNode(obj)
            i = get(obj.masterList, 'Value');
        end

        function setCardSelection(obj, index)
            set(obj.detailCardPanel, 'Selection', index);
        end

        function f = getStartupFile(obj)
            f = get(obj.generalCard.startupFileField, 'String');
        end

        function setStartupFile(obj, f)
            set(obj.generalCard.startupFileField, 'String', f);
        end
        
        function tf = getWarnOnViewOnlyWithOpenFile(obj)
            tf = get(obj.generalCard.warnOnViewOnlyWithOpenFileCheckBox, 'Value');
        end

        function setWarnOnViewOnlyWithOpenFile(obj, tf)
            set(obj.generalCard.warnOnViewOnlyWithOpenFileCheckBox, 'Value', tf);
        end

        function n = getFileDefaultName(obj)
            n = get(obj.fileCard.defaultNameField, 'String');
        end

        function setFileDefaultName(obj, n)
            set(obj.fileCard.defaultNameField, 'String', n);
        end

        function n = getFileDefaultLocation(obj)
            n = get(obj.fileCard.defaultLocationField, 'String');
        end

        function setFileDefaultLocation(obj, l)
            set(obj.fileCard.defaultLocationField, 'String', l);
        end

        function i = getSelectedSearchPath(obj)
            i = get(obj.searchPathCard.list, 'Value');
        end

        function p = getSearchPaths(obj)
            p = get(obj.searchPathCard.list, 'String');
        end

        function clearSearchPaths(obj)
            set(obj.searchPathCard.list, 'String', {});
        end

        function addSearchPath(obj, path)
            s = get(obj.searchPathCard.list, 'String');
            s = [s; {path}];
            set(obj.searchPathCard.list, 'String', s);
        end

        function removeSearchPath(obj, index)
            s = get(obj.searchPathCard.list, 'String');
            s(index) = [];
            set(obj.searchPathCard.list, 'String', s);
        end

        function i = getSearchPathExclude(obj)
            i = get(obj.searchPathCard.excludeField, 'String');
        end

        function setSearchPathExclude(obj, i)
            set(obj.searchPathCard.excludeField, 'String', i);
        end

        function f = getLoggingConfigurationFile(obj)
            f = get(obj.loggingCard.configurationFileField, 'String');
        end

        function setLoggingConfigurationFile(obj, f)
            set(obj.loggingCard.configurationFileField, 'String', f);
        end

        function d = getLoggingLogDirectory(obj)
            d = get(obj.loggingCard.logDirectoryField, 'String');
        end

        function setLoggingLogDirectory(obj, d)
            set(obj.loggingCard.logDirectoryField, 'String', d);
        end

    end

end
