function addAwsDynamicLibsLocationToSystemPathIfNecessary()
%ADDAWSDYNAMICLIBSLOCATIONTOSYSTEMPATHIFNECESSARY Adds the location of the AWS SDK dynamic libraries shipped with this support package to the system path on Windows
%   On Windows, this function adds the location of the AWS SDK dynamic
%   libraries distributed with this support package to the system path.
%   This is required because otherwise the MEX functions that use the AWS
%   SDK do not function.
%
%   On Unix, this function is a no-op.  No equivalent action is required
%   because MEX can find the dynamic libraries via rpath.

%   Copyright 2020 The MathWorks, Inc.

if ~ispc()
    return
end

persistent initialised
mlock
if isempty(initialised)
    pathEntryToAdd = fullfile(matlabshared.supportpkg.getSupportPackageRoot, "bin", computer("arch"));
    existingPath = getenv("PATH");
    existingPathEntries = strsplit(existingPath, pathsep);
    
    if ~any(strcmpi(existingPathEntries, pathEntryToAdd))
        newPath = strcat(existingPath, pathsep, pathEntryToAdd);
        setenv("PATH", newPath);
    end
    initialised = true;
end
end