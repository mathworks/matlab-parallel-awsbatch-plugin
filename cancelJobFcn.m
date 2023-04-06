function OK = cancelJobFcn(cluster, job)
%CANCELJOBFCN Cancels a job on AWS Batch
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you cancel a job.

% Copyright 2019-2023 The MathWorks, Inc.

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericAWSBatch:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end

% Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so return true
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    OK = true;
    return
end
try
    s3Prefix = data.S3Prefix;
catch err
    ex = MException('parallelexamples:GenericAWSBatch:FailedToRetrieveS3JobUUID', ...
        'Failed to retrieve S3Prefix from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end
try
    filesExistInS3 = data.FilesExistInS3;
catch err
    ex = MException('parallelexamples:GenericAWSBatch:FailedToRetrieveFilesExistInS3', ...
        'Failed to retrieve FilesExistInS3 from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end

% Get the S3 bucket (and trim any leading/trailing whitespace) for use
% later.
if ~isprop(cluster.AdditionalProperties, 'S3Bucket')
    error('parallelexamples:GenericAWSBatch:MissingAdditionalProperties', ...
        'Required field %s is missing from AdditionalProperties.', 'S3Bucket');
end
s3Bucket = cluster.AdditionalProperties.S3Bucket;
if ~ischar(s3Bucket) && ~isStringScalar(s3Bucket)
    error('parallelexamples:GenericAWSBatch:IncorrectArguments', ...
        'S3Bucket must be a character vector');
end
s3Bucket = strtrim(s3Bucket);

% Simplify the schedulerIDs to reduce the number of network calls
schedulerIDs = getSimplifiedSchedulerIDsForJob(job);

% Keep track of any errors thrown when deleting the job
erroredJobAndCauseStrings = cell(size(schedulerIDs));
% Get the cluster to delete the job
for ii = 1:length(schedulerIDs)
    jobID = schedulerIDs{ii};
    dctSchedulerMessage(4, '%s: Canceling job on cluster with jobID %s.', currFilename, jobID);
    try
        deleteBatchJob(jobID);
    catch err
        dctSchedulerMessage(1, '%s: Failed to cancel job %d on cluster.  Reason:\n\t%s', currFilename, jobID, err.message);
        erroredJobAndCauseStrings{ii} = sprintf('Job ID: %s\tReason: %s', jobID, strtrim(err.message));
    end
end

% Now delete all staged files for this job from S3 if they haven't already
% been deleted.
if filesExistInS3
    try
        deleteJobFilesFromS3(job, s3Bucket, s3Prefix);
        data.FilesExistInS3 = false;
        cluster.setJobClusterData(job, data);
    catch err
        warning('parallelexamples:GenericAWSBatch:FailedToRemoveFilesFromS3', ...
            'Failed to remove files from S3 for job %d.\nReason: %s', ...
            job.ID, err.message);
    end
end

% Now warn about those jobs that we failed to cancel.
erroredJobAndCauseStrings = erroredJobAndCauseStrings(~cellfun(@isempty, erroredJobAndCauseStrings));
if ~isempty(erroredJobAndCauseStrings)
    warning('parallelexamples:GenericAWSBatch:FailedToCancelJob', ...
        'Failed to cancel the following jobs on the cluster:\n%s', ...
        sprintf('\t%s\n', erroredJobAndCauseStrings{:}));
end
OK = isempty(erroredJobAndCauseStrings);

end
