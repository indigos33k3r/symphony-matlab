classdef AcquisitionService < handle
    
    events (NotifyAccess = private)
        SelectedProtocol
        SetProtocolProperty
        ChangedState
    end
    
    properties (Access = private)
        session
        protocolRepository
        listeners
    end
    
    methods
        
        function obj = AcquisitionService(session, protocolRepository)
            obj.session = session;
            obj.protocolRepository = protocolRepository;
            
            obj.listeners = {};
            obj.listeners = addlistener(obj.session, 'rig', 'PostSet', @obj.onSessionSetRig);
            obj.listeners = addlistener(obj.session.controller, 'state', 'PostSet', @obj.onControllerSetState);
        end
        
        function cn = getAvailableProtocols(obj)
            cn = obj.protocolRepository.getAll();
        end
        
        function selectProtocol(obj, className)
            if ~any(strcmp(className, obj.getAvailableProtocols()))
                error([className ' is not an available protocol']);
            end
            if obj.session.hasProtocol()
                delete(obj.session.getProtocol());
                obj.session.protocol = [];
            end
            constructor = str2func(className);
            protocol = constructor();
            protocol.setRig(obj.session.rig);
            obj.session.protocol = protocol;
            notify(obj, 'SelectedProtocol');
        end
        
        function cn = getSelectedProtocol(obj)
            cn = class(obj.session.getProtocol());
        end
        
        function tf = hasSelectedProtocol(obj)
            tf = obj.session.hasProtocol();
        end
        
        function d = getProtocolPropertyDescriptors(obj)
            d = obj.session.getProtocol().getPropertyDescriptors();
        end
        
        function setProtocolProperty(obj, name, value)
            obj.session.getProtocol().(name) = value;
            notify(obj, 'SetProtocolProperty');
        end
        
        function p = getProtocolPreview(obj, panel)
            p = obj.session.getProtocol().getPreview(panel);
        end

        function viewOnly(obj)
            protocol = obj.session.getProtocol();
            obj.session.controller.runProtocol(protocol, []);
        end
        
        function record(obj)
            protocol = obj.session.getProtocol();
            persistor = obj.session.getPersistor();
            obj.session.controller.runProtocol(protocol, persistor);
        end

        function stop(obj)
            obj.session.controller.requestStop();
        end
        
        function s = getState(obj)
            s = obj.session.controller.state;
        end
        
        function [tf, msg] = validate(obj)
            tf = obj.session.hasRig();
            if ~tf
                msg = 'No rig';
                return;
            end
            tf = obj.session.hasProtocol();
            if ~tf
                msg = 'No protocol';
                return;
            end
            [tf, msg] = obj.session.getProtocol().isValid();
        end
        
    end
    
    methods (Access = private)
        
        function onSessionSetRig(obj, ~, ~)
            if obj.hasSelectedProtocol()
                obj.selectProtocol(obj.getSelectedProtocol());
            end
        end
        
        function onControllerSetState(obj, ~, ~)
            notify(obj, 'ChangedState');
        end
        
    end
    
end
