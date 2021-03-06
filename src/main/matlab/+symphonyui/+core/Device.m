classdef Device < symphonyui.core.CoreObject
    % A Device represents a single physical hardware device attached to a rig.
    %
    % Device Methods:
    %   addConfigurationSetting     - Adds a new configuration setting to this device
    %   setConfigurationSetting     - Sets the value of an existing configuration setting of this device
    %   getConfigurationSetting     - Gets the value of an existing configuration setting
    %   hasConfigurationSetting     - Indicates if a configuration setting exists
    %   removeConfigurationSetting  - Removes a configuration setting from this device
    %
    %   addResource         - Adds a new resource to this device
    %   removeResource      - Removes a resource from this device
    %   getResource         - Gets a resource by name
    %   getResourceNames    - Gets the name of all resources on this device
    %
    %   bindStream          - Associates a stream with this device
    %   getInputStreams     - Gets a cell array of bound input streams
    %   getOutputStreams    - Gets a cell array of bound output streams
    %
    %   applyBackground     - Immediately applies the device background to all bound output streams
    
    events (NotifyAccess = private)
        AddedConfigurationSetting       % Triggers when a configuration setting is added
        SetConfigurationSetting         % Triggers when a configuration setting value is set
        RemovedConfigurationSetting     % Triggers when a configuration setting is removed
        AddedResource                   % Triggers when a resource is added
        RemovedResource                 % Triggers when a resource is removed
    end

    properties (SetAccess = private)
        name            % Human-readable device name 
        manufacturer    % Name of device manufacturer
    end

    properties (SetObservable)
        sampleRate  % Common input and output sample rate (Measurement)
        background  % Background applied to bound output streams when stopped (Measurement)
    end
    
    properties (Access = private)
        configurationSettingDescriptors
    end
    
    properties (Constant, Hidden)
        CONFIGURATION_SETTING_DESCRIPTORS_RESOURCE_NAME = 'configurationSettingDescriptors';
    end

    methods

        function obj = Device(cobj)
            obj@symphonyui.core.CoreObject(cobj);
        end

        function delete(obj)
            obj.close();
        end

        function close(obj) %#ok<MANU>
            % For subclasses.
        end

        function n = get.name(obj)
            n = char(obj.cobj.Name);
        end

        function m = get.manufacturer(obj)
            m = char(obj.cobj.Manufacturer);
        end

        function addConfigurationSetting(obj, name, value, varargin)
            % Adds a new configuration setting to this device. Additional arguments are passed to the settings
            % PropertyDescriptor constructor.
            
            descriptors = obj.getConfigurationSettingDescriptors();
            if ~isempty(descriptors.findByName(name))
                error([name ' already exists']);
            end
            d = symphonyui.core.PropertyDescriptor(name, value, varargin{:});
            descriptors(end + 1) = d;
            obj.tryCore(@()obj.cobj.Configuration.Add(name, obj.propertyValueFromValue(value)));
            obj.updateConfigurationSettingDescriptors(descriptors);
            notify(obj, 'AddedConfigurationSetting', symphonyui.core.CoreEventData(d));
        end

        function setConfigurationSetting(obj, name, value)
            % Sets the value of an existing configuration setting of this device. The new value must be compatible with
            % setting's type.
            
            descriptors = obj.getConfigurationSettingDescriptors();
            d = descriptors.findByName(name);
            if isempty(d)
                error([name ' does not exist']);
            end
            if d.isReadOnly
                error([name ' is read only']);
            end
            d.value = value;
            obj.tryCore(@()obj.cobj.Configuration.Item(name, obj.propertyValueFromValue(value)));
            obj.updateConfigurationSettingDescriptors(descriptors);
            notify(obj, 'SetConfigurationSetting', symphonyui.core.CoreEventData(d));
        end
        
        function m = getConfigurationSettingMap(obj)
            m = obj.mapFromKeyValueEnumerable(obj.cobj.Configuration, @obj.valueFromPropertyValue);
        end

        function v = getConfigurationSetting(obj, name)
            % Gets the value of an existing configuration setting
            
            m = obj.getConfigurationSettingMap();
            if ~m.isKey(name)
                error([name ' does not exist']);
            end
            v = m(name);
        end
        
        function tf = hasConfigurationSetting(obj, name)
            % Indicates if a configuration setting exists
            
            m = obj.getConfigurationSettingMap();
            tf = m.isKey(name);
        end

        function tf = removeConfigurationSetting(obj, name)
            % Removes a configuration setting from this device
            
            descriptors = obj.getConfigurationSettingDescriptors();
            index = arrayfun(@(d)strcmp(d.name, name), descriptors);
            d = descriptors(index);
            if isempty(d)
                return;
            end
            if ~d.isRemovable
                error([name ' is not removable']);
            end
            descriptors(index) = [];
            tf = obj.tryCoreWithReturn(@()obj.cobj.Configuration.Remove(name));
            obj.updateConfigurationSettingDescriptors(descriptors);
            notify(obj, 'RemovedConfigurationSetting', symphonyui.core.CoreEventData(d));
        end

        function d = getConfigurationSettingDescriptors(obj)
            if ~isempty(obj.configurationSettingDescriptors)
                d = obj.configurationSettingDescriptors;
                return;
            end
            
            if any(strcmp(obj.getResourceNames(), obj.CONFIGURATION_SETTING_DESCRIPTORS_RESOURCE_NAME))
                d = obj.getResource(obj.CONFIGURATION_SETTING_DESCRIPTORS_RESOURCE_NAME);
            else
                d = symphonyui.core.PropertyDescriptor.empty(0, 1);
                m = obj.getConfigurationSettingMap();
                keys = m.keys;
                for i = 1:numel(keys)
                    k = keys{i};
                    d(end + 1) = symphonyui.core.PropertyDescriptor(k, m(k), 'isReadOnly', true, 'isRemovable', false); %#ok<AGROW>
                end
            end
            obj.configurationSettingDescriptors = d;
        end

        function addResource(obj, name, variable)
            % Adds a new resource to this device
            
            bytes = getByteStreamFromArray(variable);
            obj.tryCoreWithReturn(@()obj.cobj.AddResource('com.mathworks.byte-stream', name, bytes));
            notify(obj, 'AddedResource', symphonyui.core.CoreEventData(struct('name', name, 'data', bytes)));
        end
        
        function tf = removeResource(obj, name)
            % Removes a resource from this device
            
            if strcmp(name, obj.CONFIGURATION_SETTING_DESCRIPTORS_RESOURCE_NAME)
                error('Cannot remove configuration setting descriptors resource');
            end
            tf = obj.tryCoreWithReturn(@()obj.cobj.RemoveResource(name));
            if tf
                notify(obj, 'RemovedResource', symphonyui.core.CoreEventData(struct('name', name)));
            end
        end

        function v = getResource(obj, name)
            % Gets a resource by name
            
            cres = obj.tryCoreWithReturn(@()obj.cobj.GetResource(name));
            v = getArrayFromByteStream(uint8(cres.Data));
        end

        function n = getResourceNames(obj)
            % Gets the name of all resources on this device
            
            n = obj.cellArrayFromEnumerable(obj.cobj.GetResourceNames(), @char);
        end

        function d = bindStream(obj, stream, name)
            % Associates a stream with this device. Naming the association is optional.
            
            if nargin < 3
                obj.tryCore(@()obj.cobj.BindStream(stream.cobj));
            else
                obj.tryCore(@()obj.cobj.BindStream(name, stream.cobj));
            end
            d = obj;
        end
        
        function unbindStream(obj, name)
            obj.tryCore(@()obj.cobj.UnbindStream(name));
        end

        function s = getInputStreams(obj)
            % Gets a cell array of bound input streams
            
            s = obj.cellArrayFromEnumerable(obj.cobj.InputStreams, @symphonyui.core.DaqStream);
        end

        function s = getOutputStreams(obj)
            % Gets a cell array of bound output streams
            
            s = obj.cellArrayFromEnumerable(obj.cobj.OutputStreams, @symphonyui.core.DaqStream);
        end

        function r = get.sampleRate(obj)
            cir = obj.cobj.InputSampleRate;
            cor = obj.cobj.OutputSampleRate;
            if (~cir.Equals(cor))
                error('Mismatched input and output sample rate');
            end
            if isempty(cir)
                r = [];
            else
                r = symphonyui.core.Measurement(cir);
            end
        end

        function set.sampleRate(obj, r)
            obj.cobj.InputSampleRate = r.cobj;
            obj.cobj.OutputSampleRate = r.cobj;
        end

        function b = get.background(obj)
            cbg = obj.tryCoreWithReturn(@()obj.cobj.Background);
            b = symphonyui.core.Measurement(cbg);
        end

        function set.background(obj, b)
            obj.cobj.Background = b.cobj;
        end

        function applyBackground(obj)
            % Immediately applies the device background to all bound output streams
            
            obj.tryCore(@()obj.cobj.ApplyBackground());
        end

    end

    methods (Access = protected)

        function setReadOnlyConfigurationSetting(obj, name, value)
            % A backdoor for device's to change the value of read-only configuration settings.
            
            descriptors = obj.getConfigurationSettingDescriptors();
            d = descriptors.findByName(name);
            if isempty(d)
                error([name ' does not exist']);
            end
            d.value = value;
            obj.tryCore(@()obj.cobj.Configuration.Item(name, obj.propertyValueFromValue(value)));
            obj.updateConfigurationSettingDescriptors(descriptors);
            notify(obj, 'SetConfigurationSetting', symphonyui.core.CoreEventData(d));
        end

    end
    
    methods (Access = private)

        function updateConfigurationSettingDescriptors(obj, descriptors)
            obj.tryCoreWithReturn(@()obj.cobj.RemoveResource(obj.CONFIGURATION_SETTING_DESCRIPTORS_RESOURCE_NAME));
            obj.addResource(obj.CONFIGURATION_SETTING_DESCRIPTORS_RESOURCE_NAME, descriptors);
            obj.configurationSettingDescriptors = descriptors;
        end

    end

end
