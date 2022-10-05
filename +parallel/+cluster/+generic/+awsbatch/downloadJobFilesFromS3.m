function downloadJobFilesFromS3(job, s3Bucket, s3Prefix)
%DOWNLOADJOBFILESFROMS3 Download from S3 the output files for a job that ran on MATLAB Parallel Server with AWS Batch.
%   downloadJobFilesFromS3(JOB, S3BUCKET, S3PREFIX) downloads output files
%   for a job from the S3 bucket S3BUCKET to the cluster's
%   JobStorageLocation. This function expects the output files to have URIs
%   of the form s3://S3BUCKET/S3PREFIX/stageOut/JobX/TaskY.zip, where X is
%   the job's ID and Y is the task's ID.

%   Copyright 2019 The MathWorks, Inc.

narginchk(3, 3);
validateattributes(job, {'parallel.job.CJSIndependentJob'}, {'scalar'}, ...
    'parallel.cluster.generic.awsbatch.downloadJobFilesFromS3', 'job');
validateattributes(s3Bucket, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.downloadJobFilesFromS3', 's3Bucket');
validateattributes(s3Prefix, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.downloadJobFilesFromS3', 's3Prefix');

currFilename = mfilename;
jobStorageLocation = job.Parent.JobStorageLocation;
jobFilesInfo = job.Parent.pGetJobFilesInfo(job);
taskFilesDirectoryName = jobFilesInfo.TaskFiles{:};
taskFilesDirectory = fullfile(jobStorageLocation, taskFilesDirectoryName);

% We store the input and output files in the S3 bucket under different
% prefixes because this guarantees read-after-write consistency when we
% download the output files after the job has finished. We download all
% files that match s3://[s3Bucket]/[s3Prefix]/stageOut/JobX/Task*.zip.
% Any changes to where the files are expected must be reflected in the
% docker image used for the AWS Batch Job Definition.
zipFilesS3URIPattern = "s3://" + s3Bucket + '/' + s3Prefix + "/stageOut/" + taskFilesDirectoryName + "/Task*.zip";
remoteZipFilesStruct = dir(zipFilesS3URIPattern);

if isempty(remoteZipFilesStruct)
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchNoOutputFilesForJob', ...
        job.ID, zipFilesS3URIPattern));
end

remoteZipFileNames = {remoteZipFilesStruct.name}';
zipFileS3URIs = strcat({remoteZipFilesStruct.folder}', '/', remoteZipFileNames);
localZipFilePaths = fullfile(jobStorageLocation, taskFilesDirectoryName, {remoteZipFilesStruct.name}');

dctSchedulerMessage(4, '%s: Downloading the following output files for job %d: %s.', ...
    currFilename, job.ID, strjoin(zipFileS3URIs, ", "));
try
    for ii = 1:numel(zipFileS3URIs)
        parallel.internal.supportpackages.awsbatch.copyfile(zipFileS3URIs{ii}, localZipFilePaths{ii});
    end
catch err
    dctSchedulerMessage(0, '%s: Failed to copy output file from %s to %s for job %d.', ...
        currFilename, zipFileS3URIs{ii}, localZipFilePaths{ii}, job.ID);
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchDownloadFilesFailed', ...
        zipFileS3URIs{ii}, localZipFilePaths{ii}, job.ID, err.message));
end

% Unzip the zip files and then remove them.
for ii = 1:numel(localZipFilePaths)
    unzip(localZipFilePaths{ii}, taskFilesDirectory);
    delete(localZipFilePaths{ii});
end
