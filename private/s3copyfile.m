function s3copyfile(source, destination)
%S3COPYFILE Copy file to/from S3.
%   s3copyfile(SOURCE, DESTINATION) copies the file SOURCE to the new file
%   DESTINATION. SOURCE and DESTINATION may be an absolute pathname or an
%   S3 URI such as s3://bucketName/keyName.

%   Copyright 2019-2023 The MathWorks, Inc.

narginchk(2, 2);
validateattributes(source, {'string', 'char'}, {'scalartext'}, ...
    's3copyfile', 'source');
validateattributes(destination, {'string', 'char'}, {'scalartext'}, ...
    's3copyfile', 'destination');

if verLessThan('matlab', '9.8')
    % copyfile in 19b doesn't support S3, so use the AWS CLI
    iCopyUsingCLI(source, destination);
else
    % Support for S3 added to the copyfile builtin for 20a
    copyfile(source, destination);
end

end

function iCopyUsingCLI(source, destination)

cmd = sprintf('aws s3 cp --no-cli-pager "%s" "%s"', ...
    source, destination);
[exitCode, out] = system(cmd);
if exitCode ~= 0
    error('parallelexamples:GenericAWSBatch:CopyFileFailed', ...
        'Failed to copy ''%s'' to ''%s''.\n%s', ...
        source, destination, out);
end

end
