classdef Experiment < handle
    
    events
        Opened
        Closed
        BeganEpochGroup
        EndedEpochGroup
        RecordedEpoch
        AddedNote
    end
    
    properties
        id
        name
        location
        purpose
        startTime
        endTime
        epochGroups
        currentEpochGroup
        notes
    end
    
    methods
        
        function obj = Experiment(name, location, purpose)
            obj.id = char(java.util.UUID.randomUUID);
            obj.name = name;
            obj.location = location;
            obj.purpose = purpose;
            obj.epochGroups = symphonyui.core.EpochGroup.empty(0, 1);
            obj.notes = symphonyui.core.Note.empty(0, 1);
        end
        
        function open(obj)
            obj.startTime = now;
            notify(obj, 'Opened');
        end
        
        function close(obj)
            obj.endTime = now;
            notify(obj, 'Closed');
        end
        
        function beginEpochGroup(obj, label)
            disp(['Begin Epoch Group: ' label]);
            if isempty(obj.currentEpochGroup)
                parent = obj;
            else
                parent = obj.currentEpochGroup;
            end
            group = symphonyui.core.EpochGroup(parent, label);
            if isempty(obj.currentEpochGroup)
                obj.epochGroups(end + 1) = group;
            end
            obj.currentEpochGroup = group;
            group.start();
            notify(obj, 'BeganEpochGroup', symphonyui.core.EpochGroupEventData(group));
        end
        
        function endEpochGroup(obj)
            disp(['End Epoch Group: ' obj.currentEpochGroup.label]);
            group = obj.currentEpochGroup;
            group.stop();
            if group.parent == obj
                obj.currentEpochGroup = [];
            else    
                obj.currentEpochGroup = group.parent;
            end
            notify(obj, 'EndedEpochGroup', symphonyui.core.EpochGroupEventData(group));
        end
        
        function tf = hasCurrentEpochGroup(obj)
            tf = ~isempty(obj.currentEpochGroup);
        end
        
        function addNote(obj, note)
            obj.notes(end + 1) = note;
            notify(obj, 'AddedNote');
        end
        
    end
    
end

