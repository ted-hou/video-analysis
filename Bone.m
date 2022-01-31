classdef Bone < handle
    properties
        Name = '';
        Parent = [];
        Child = [];
    end
    
    methods
        function obj = Bone(name, parent)            
            obj.Name = name;
            
            if nargin > 1
                parent.setChild(obj)
            end
        end
        
        function setChild(obj, child)
            obj.Child = child;
            child.Parent = obj;
        end
        
        function pos = getPos(obj, vtd)
            pos = table2array(vtd(:, {sprintf('%s_X', obj.Name), sprintf('%s_Y', obj.Name)}));
        end
        
        function dir = getDirGlobal(obj, vtd)
            % Return direction vector pointing towards child bone
            if ~isempty(obj.Child)
                vec = obj.Child.getPos(vtd) - obj.getPos(vtd);
                % normalize vectors
                vec = vec ./ vecnorm(vec, 2, 2);
                % dir = acos(vec * [0, 1]');
                dir = sign(vec(:, 1)) .* acos(vec(:, 2)) * 180 / pi;
                dir = Bone.normalizeDir(dir);
            % Childless bones use parent dir
            elseif ~isempty(obj.Parent)
                dir = obj.Parent.getDirGlobal(vtd);
            else
                dir = zeros(height(vtd), 1);
            end
        end
        
        function dir = getDirLocal(obj, vtd)
            if ~isempty(obj.Parent)
                dir = Bone.normalizeDir(obj.getDirGlobal(vtd) - obj.Parent.getDirGlobal(vtd));
            else
                dir = zeros(height(vtd), 1);
            end
        end
        
        function h = hasParent(obj)
            if length(obj) == 1
                h = ~isempty(obj.Parent);
            else
                for i = 1:length(obj)
                    h(i) = obj(i).hasParent();
                end
            end
        end
        
        function h = hasChild(obj)
            if length(obj) == 1
                h = ~isempty(obj.Child);
            else
                for i = 1:length(obj)
                    h(i) = obj(i).hasChild();
                end
            end
        end
    end
    
    methods (Static)
        function dir = normalizeDir(dir)
            dir = mod(dir, 360);
        end
    end
end

