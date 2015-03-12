classdef Config < handle
    
    events (NotifyAccess = private)
        Changed
    end
    
    properties (Constant, Access = private)
        group = 'symphonyui'
    end
    
    methods
        
        function v = get(obj, key, default)
            if nargin < 3
                default = symphonyui.app.Settings.getDefault(key);
            end
            
            if ispref(obj.group, key)
                v = getpref(obj.group, key);
            else
                v = default;
            end
        end
        
        function put(obj, key, value)
            % Function handles do not persist well.
            if isa(value, 'function_handle')
                value = func2str(value);
            end
            
            if ispref(obj.group, key)
                if isequal(getpref(obj.group, key), value)
                    return;
                end
                setpref(obj.group, key, value);
            else
                addpref(obj.group, key, value);
            end
            
            notify(obj, 'Changed', symphonyui.app.KeyValueEventData(key, value));
        end
        
        function clear(obj)
            rmpref(obj.group);
        end
        
    end
    
end