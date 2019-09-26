local status, lfs = pcall (require, "lfs")
if (not status) then
  error("util.path requires LuaFileSystem")
end

local path = {}

path.mkdir = lfs.mkdir

function path.isdir(path)
    if path:match("\\$") then
        path = path:sub(1,-2)
    end
    return lfs.attributes(path,'mode') == 'directory'
end

function path.isfile(path)
    return lfs.attributes(path,'mode') == 'file'
end

return path
