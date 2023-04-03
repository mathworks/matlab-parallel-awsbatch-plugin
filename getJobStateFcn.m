function state = getJobStateFcn(cluster, job, state)
%GETJOBSTATEFCN Gets the state of a job from AWS Batch
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you query the state of a job.

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
    % This indicates that the job has not been submitted, so just return
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    return
end
try
    s3Prefix = data.S3Prefix;
catch err
    ex = MException('parallelexamples:GenericAWSBatch:FailedToRetrieveJobUUID', ...
        'Failed to retrieve S3Prefix from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end
try
    hasDownloadedOutputFilesFromS3 = data.HasDownloadedOutputFilesFromS3;
catch err
    ex = MException('parallelexamples:GenericAWSBatch:FailedToRetrieveJobFileStagingStatus', ...
        'Failed to retrieve HasDownloadedOutputFilesFromS3 from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end
try
    taskIDToLogStreamMapOnDisk = data.TaskIDToLogStreamMap;
catch err
    ex = MException('parallelexamples:GenericAWSBatch:FailedToRetrieveTaskIDToLogStreamMap', ...
        'Failed to retrieve TaskIDToLogStreamMap from the job cluster data.');
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

% Shortcut if the job state is already finished or failed and we have
% already downloaded the output files from S3.
jobInTerminalState = strcmp(state, 'finished') || strcmp(state, 'failed');
if jobInTerminalState && hasDownloadedOutputFilesFromS3
    return
end

% Get the job states and LogStreamNames from AWS Batch.
jobInfoTable = getBatchJobInfo(job);
[clusterState, isTerminal] = iExtractJobState(jobInfoTable.Status);
dctSchedulerMessage(6, '%s: State %s was extracted from cluster output.', currFilename, clusterState);

% Create a map of task ID to log stream name from the output of
% getBatchJobInfo. Then amalgamate it with the map from the job's cluster
% data, and store it for future use.  We only want to include task IDs in
% the map that do not have empty log stream names.
taskIDsToLogStreamsTable = jobInfoTable(jobInfoTable.LogStreamName~="", {'TaskID', 'LogStreamName'});
taskIDToLogStreamMap = containers.Map(taskIDsToLogStreamsTable.TaskID, taskIDsToLogStreamsTable.LogStreamName);
taskIDToLogStreamMap = [taskIDToLogStreamMapOnDisk; taskIDToLogStreamMap];
if ~isequal(taskIDToLogStreamMapOnDisk, taskIDToLogStreamMap)
    data.TaskIDToLogStreamMap = taskIDToLogStreamMap;
    cluster.setJobClusterData(job, data);
end
% If we could determine the cluster's state, we'll use that, otherwise
% stick with MATLAB's job state.
if ~strcmp(clusterState, 'unknown')
    state = clusterState;
end

% If job is finished, copy the job output files from S3 and then remove all
% staged files for the job from S3.  Otherwise do nothing.
if isTerminal && ~hasDownloadedOutputFilesFromS3
    dctSchedulerMessage(4, '%s: Downloading output files from S3 for job %d.', currFilename, job.ID);
    try
        downloadJobFilesFromS3(job, s3Bucket, s3Prefix);
    catch err
        warning('parallelexamples:GenericAWSBatch:FailedToDownloadFilesFromS3', ...
            ['Failed to download output files from S3 for job %d.', ...
            ' The job''s files in the JobStorageLocation may not be up-to-date.', ...
            ' Files may be left in S3 at s3://%s/%s.\n%s'], ...
            job.ID, s3Bucket, s3Prefix, err.message);
    end
    
    % Store the fact that we have downloaded the output files so we can shortcut in the future
    data.HasDownloadedOutputFilesFromS3 = true;
    cluster.setJobClusterData(job, data);
    
    % Download log files for the job
    taskIDs = taskIDToLogStreamMap.keys;
    logStreams = taskIDToLogStreamMap.values(taskIDs);
    downloadJobLogFiles(job, cell2mat(taskIDs), logStreams);
    
    % Now delete all staged files for this job from S3
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

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [state, isTerminal] = iExtractJobState(jobStates)
% Function to determine the MATLAB job state from an array of AWS Batch job
% states corresponding to each of the submitted tasks in the MATLAB job.

isPending  = ismember(jobStates, ["SUBMITTED", "PENDING", "RUNNABLE"]);
isRunning  = ismember(jobStates, ["STARTING", "RUNNING"]);
isFinished = strcmp(jobStates, "SUCCEEDED");
isFailed   = strcmp(jobStates, "FAILED");
% Note that jobStates may also include the string "UNKNOWN", which is not
% an AWS defined state, but is returned by getBatchJobInfo() in the case
% that AWS does not return any information for a job. The most likely cause
% of this is that the job was in the SUCCEEDED or FAILED state for over 24
% hours. We do not bother checking for the "UNKNOWN" state however, because
% the result remains the same as if we are unable to determine the job to
% be pending, running, finished or failed; we return state = 'unknown' and
% isTerminal = true.

isTerminal = false;
state = 'unknown';

% Any running indicates that the job is running
if any(isRunning)
    state = 'running';
    return
end

% We know numRunning == 0 so if there are some still pending then the
% job must be queued again, even if there are some finished
if any(isPending)
    state = 'queued';
    return
end

% If we get here, AWS has reported no tasks to be pending or running. We
% therefore assume the job to be in a terminal state.
isTerminal = true;

% If all of the jobs have finished, then we know the job has finished.
if all(isFinished)
    state = 'finished';
    return
end

% If any of the jobs have failed, the state is failed.
if any(isFailed)
    state = 'failed';
    return
end

end
