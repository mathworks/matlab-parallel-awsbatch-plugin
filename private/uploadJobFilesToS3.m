function s3Prefix = uploadJobFilesToS3(job, s3Bucket)
%UPLOADJOBFILESTOS3 Upload a job's input files to S3 for MATLAB Parallel Server with AWS Batch.
%   S3PREFIX = uploadJobFilesToS3(JOB, S3BUCKET) uploads the input files
%   for the job to the S3 bucket, under the prefix S3PREFIX/stageIn/,
%   where S3PREFIX is a randomly generated string. S3PREFIX is returned as
%   a string scalar.

%   Copyright 2019-2023 The MathWorks, Inc.

narginchk(2, 2);
validateattributes(job, {'parallel.job.CJSIndependentJob'}, {'scalar'}, ...
    'uploadJobFilesToS3', 'job');
validateattributes(s3Bucket, {'string', 'char'}, {'scalartext'}, ...
    'uploadJobFilesToS3', 's3Bucket');

currFilename = mfilename;
jobStorageLocation = job.Parent.JobStorageLocation;
jobFilesInfo = job.Parent.pGetJobFilesInfo(job);

% Determine which task files exist.
taskFilesDirectoryName = jobFilesInfo.TaskFiles{:};
taskFilesDirectoryStruct = dir(fullfile(jobStorageLocation, taskFilesDirectoryName));
taskFilesDirectoryContents = {taskFilesDirectoryStruct.name}';

% The dir command returns '.' and '..', which we need to filter out.
taskFilesDirectoryContents(ismember(taskFilesDirectoryContents, {'.', '..'})) = [];
taskFiles = fullfile(taskFilesDirectoryName, taskFilesDirectoryContents);

% Construct lists of the input files required for the job, relative to
% the JobStorageLocation and as absolute paths.
relativePaths = [jobFilesInfo.JobInputFiles; taskFiles];
absolutePaths = fullfile(jobStorageLocation, relativePaths);

% Create a random string to use as the key name prefix for the job's files
% in S3
[~, s3Prefix] = fileparts(tempname());

% We store the input and output files in the S3 bucket under different
% prefixes because this guarantees read-after-write consistency when we
% download the output files after the job has finished. We upload all of
% input files to the S3 bucket with the prefix jobUUID + "/stageIn/". Any
% changes to this prefix must be reflected in the docker image used for the
% AWS Batch Job Definition.
keyNamePrefix = strcat(s3Prefix, '/stageIn');

% To use the relative paths as part of the key names in S3, we need to
% convert any '\' to '/' in case the client is windows.
keyNamesRelativeToPrefix = strrep(relativePaths, '\', '/');
s3URIs = strcat('s3://', s3Bucket, '/', keyNamePrefix, '/', keyNamesRelativeToPrefix);

dctSchedulerMessage(4, '%s: Uploading input files for job %d to the S3 bucket %s under prefix %s.', ...
    currFilename, job.ID, s3Bucket, keyNamePrefix);
try
    for ii = 1:numel(absolutePaths)
        s3copyfile(absolutePaths{ii}, s3URIs{ii});
    end
catch uploadError
    dctSchedulerMessage(0, '%s: Failed to copy file %s to %s for job %d.  Reason: %s', ...
        currFilename, absolutePaths{ii}, s3URIs{ii}, job.ID, uploadError.message);
    
    % Try to remove any files that may exist in S3, unless the upload error
    % indicates that AWS credentials are not set. (If credentials are not
    % set, then there will be no files and the command would fail anyway).
    if ~iErrorImpliesAWSCredentialsNotSet(uploadError)
        try
            deleteJobFilesFromS3(job, s3Bucket, s3Prefix);
        catch rmdirError
            dctSchedulerMessage(0, '%s: Failed to delete all objects associated with job %d from the S3 bucket %s under prefix %s. Reason: %s', ...
                currFilename, job.ID, s3Bucket, s3Prefix, rmdirError.message);
            
            % Don't give the reason for the rmdirError in the error
            % message we throw because it can be misleading in the case
            % where the credentials are invalid.
            error('parallelexamples:GenericAWSBatch:UploadFilesFailedDeleteFailed', ...
                ['Failed to upload the file ''%s'' to the S3 bucket ''%s'' for job %d.' ...
                ' Check that:\n' ...
                '\t1. You have set up an AWS credentials file or have set the environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.' ...
                ' If you are using temporary security credentials, you must also set the environment variable AWS_SESSION_TOKEN.\n' ...
                '\t2. The S3 bucket ''%s'' exists.\n%s\n\n' ...
                'Failed to ensure that no files for this job have been left in S3.' ...
                ' Delete any files under the folder ''%s'' in the S3 bucket ''%s'' using the AWS Console.'], ...
                absolutePaths{ii}, s3Bucket, job.ID, s3Bucket, uploadError.message, s3Prefix, s3Bucket);
        end
    end
    error('parallelexamples:GenericAWSBatch:UploadFilesFailed', ...
        ['Failed to upload the file ''%s'' to the S3 bucket ''%s'' for job %d.' ...
        ' No files for this job have been left in S3.\n%s'], ...
        absolutePaths{ii}, s3Bucket, job.ID, uploadError.message);
end

s3Prefix = convertCharsToStrings(s3Prefix);
end

function tf = iErrorImpliesAWSCredentialsNotSet(err)
tf = strcmp(err.identifier, 'MATLAB:virtualfileio:path:s3EnvVariablesNotSet');
end
