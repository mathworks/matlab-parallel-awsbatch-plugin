function copyfile(source, destination)
%COPYFILE Copy file.
%   copyfile(SOURCE, DESTINATION) copies the file SOURCE to the new file
%   DESTINATION. SOURCE and DESTINATION may be an absolute pathname or an
%   S3 URI such as s3://bucketName/keyName.
%

%   Copyright 2019-2020 The MathWorks, Inc.

narginchk(2, 2);
validateattributes(source, {'string', 'char'}, {'scalartext'}, ...
    'parallel.internal.supportpackages.awsbatch.copyfile', 'source');
validateattributes(destination, {'string', 'char'}, {'scalartext'}, ...
    'parallel.internal.supportpackages.awsbatch.copyfile', 'destination');

import matlab.io.internal.vfs.stream.createStream

[source, destination] = convertStringsToChars(source, destination);
sourceStream = createStream(source, 'r');
destinationStream = createStream(destination, 'w');

numBytes = double(sourceStream.FileSize);
THIRTY_TWO_MB = 32 * 1024 * 1024;

while numBytes > 0
    bufferSize = min(numBytes, THIRTY_TWO_MB);
    buffer = read(sourceStream, bufferSize, 'uint8');
    write(destinationStream, buffer);
    numBytes = numBytes - bufferSize;
end

try
    close(destinationStream);
catch err
    if ismember(err.identifier, ["MATLAB:virtualfileio:stream:fileNotFound", "MATLAB:virtualfileio:stream:permissionDenied"])
        matlab.io.internal.vfs.validators.validateCloudEnvVariables(source);
        matlab.io.internal.vfs.validators.validateCloudEnvVariables(destination);
    end
    rethrow(err);
end
end
