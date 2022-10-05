function independentSubmitFcn(cluster, job, environmentProperties)
%INDEPENDENTSUBMITFCN Submit a MATLAB job to an AWS Batch cluster
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you submit an independent job.
%
% See also parallel.cluster.generic.independentDecodeFcn.

% Copyright 2019-2022 The MathWorks, Inc.

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericAWSBatch:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end

decodeFunction = 'parallel.cluster.generic.independentDecodeFcn';
remoteJobStorageLocation = '/usr/local/JobStorageLocation';

if ~isprop(cluster.AdditionalProperties, 'S3Bucket')
    error('parallelexamples:GenericAWSBatch:MissingAdditionalProperties', ...
        'Required field %s is missing from AdditionalProperties.', 'S3Bucket');
end
s3Bucket = cluster.AdditionalProperties.S3Bucket;

if ~isprop(cluster.AdditionalProperties, 'JobQueue')
    error('parallelexamples:GenericAWSBatch:MissingAdditionalProperties', ...
        'Required field %s is missing from AdditionalProperties.', 'JobQueue');
end
jobQueue = cluster.AdditionalProperties.JobQueue;

if ~isprop(cluster.AdditionalProperties, 'IndependentJobDefinition')
    error('parallelexamples:GenericAWSBatch:MissingAdditionalProperties', ...
        'Required field %s is missing from AdditionalProperties.', 'IndependentJobDefinition');
end
jobDefinition = cluster.AdditionalProperties.IndependentJobDefinition;

if isprop(cluster.AdditionalProperties, 'MaxJobArraySize')
    maxJobArraySize = cluster.AdditionalProperties.MaxJobArraySize;
else
    maxJobArraySize = 10000;
end

% Determine the debug setting. Setting to true makes the MATLAB workers
% output additional logging. If EnableDebug is set in the cluster object's
% AdditionalProperties, that takes precedence. Otherwise, look for the
% PARALLEL_SERVER_DEBUG and MDCE_DEBUG environment variables in that order.
% If nothing is set, debug is false.
enableDebug = 'false';
if isprop(cluster.AdditionalProperties, 'EnableDebug')
    % Use AdditionalProperties.EnableDebug, if it is set
    enableDebug = char(string(cluster.AdditionalProperties.EnableDebug));
else
    % Otherwise check the environment variables set locally on the client
    environmentVariablesToCheck = {'PARALLEL_SERVER_DEBUG', 'MDCE_DEBUG'};
    for idx = 1:numel(environmentVariablesToCheck)
        debugValue = getenv(environmentVariablesToCheck{idx});
        if ~isempty(debugValue)
            enableDebug = debugValue;
            break
        end
    end
end

if ~strcmpi(cluster.OperatingSystem, 'unix')
    error('parallelexamples:GenericAWSBatch:SubmitFcnError', ...
        'The submit function %s only supports clusters with unix OS.', currFilename)
end
if ~ischar(s3Bucket) && ~(isstring(s3Bucket) && isscalar(s3Bucket))
    error('parallelexamples:GenericAWSBatch:IncorrectArguments', ...
        'S3Bucket must be a character vector');
end
if ~ischar(jobQueue) && ~(isstring(jobQueue) && isscalar(jobQueue))
    error('parallelexamples:GenericAWSBatch:IncorrectArguments', ...
        'JobQueue must be a character vector');
end
if ~ischar(jobDefinition) && ~(isstring(jobDefinition) && isscalar(jobDefinition))
    error('parallelexamples:GenericAWSBatch:IncorrectArguments', ...
        'IndependentJobDefinition must be a character vector');
end
if ~isnumeric(maxJobArraySize) || (rem(maxJobArraySize, 1) ~= 0) || (maxJobArraySize < 1)
    error('parallelexamples:GenericAWSBatch:IncorrectArguments', ...
        'MaxJobArraySize must be a positive integer');
end
% Trim leading and trailing whitespace from the string based
% AdditionalProperties as this prevents errors occurring on the workers.
s3Bucket = strtrim(s3Bucket);
jobQueue = strtrim(jobQueue);
jobDefinition = strtrim(jobDefinition);

% The job specific environment variables
% Remove leading and trailing whitespace from the MATLAB arguments
matlabArguments = strtrim(environmentProperties.MatlabArguments);
commonEnvironmentVariables = {'PARALLEL_SERVER_DECODE_FUNCTION', decodeFunction; ...
    'PARALLEL_SERVER_STORAGE_CONSTRUCTOR', environmentProperties.StorageConstructor; ...
    'PARALLEL_SERVER_JOB_LOCATION', environmentProperties.JobLocation; ...
    'PARALLEL_SERVER_MATLAB_EXE', environmentProperties.MatlabExecutable; ...
    'PARALLEL_SERVER_MATLAB_ARGS', matlabArguments; ...
    'PARALLEL_SERVER_DEBUG', enableDebug; ...
    'MLM_WEB_LICENSE', environmentProperties.UseMathworksHostedLicensing; ...
    'MLM_WEB_USER_CRED', environmentProperties.UserToken; ...
    'MLM_WEB_ID', environmentProperties.LicenseWebID; ...
    'PARALLEL_SERVER_LICENSE_NUMBER', environmentProperties.LicenseNumber; ...
    'PARALLEL_SERVER_STORAGE_LOCATION', remoteJobStorageLocation; ...
    'PARALLEL_SERVER_S3_BUCKET', s3Bucket};
% Trim the environment variables of empty values.
nonEmptyValues = cellfun(@(x) ~isempty(strtrim(x)), commonEnvironmentVariables(:,2));
commonEnvironmentVariables = commonEnvironmentVariables(nonEmptyValues, :);

% The local job directory
localJobDirectory = cluster.getJobFolder(job);
% How we refer to the job directory on the cluster
remoteJobDirectory = sprintf('%s/Job%d', remoteJobStorageLocation, job.ID);

% The script name is independentJobWrapper.sh
scriptName = 'independentJobWrapper.sh';
% The wrapper script is in the same directory as this file
dirpart = fileparts(mfilename('fullpath'));
localScript = fullfile(dirpart, scriptName);
% Copy the local wrapper script to the job directory
copyfile(localScript, localJobDirectory);

% The command that will be executed on the remote host to run the job.
remoteScriptName = sprintf('%s/%s', remoteJobDirectory, scriptName);

% Get the tasks to submit. We do not want to submit cancelled tasks.
% Cancelled tasks will have errors.
allTasks = job.Tasks;
isPendingTask = cellfun(@isempty, get(allTasks, {'Error'}));
tasksToSubmit = allTasks(isPendingTask);

% Copy files to S3 staging area before submitting jobs.
s3Prefix = parallel.cluster.generic.awsbatch.uploadJobFilesToS3(job, s3Bucket);
try
    commonEnvironmentVariables = [commonEnvironmentVariables; ...
        {'PARALLEL_SERVER_S3_PREFIX', convertStringsToChars(s3Prefix)}];
    
    taskIDsToSubmit = cell2mat(get(tasksToSubmit, {'ID'}));
    taskIDGroupsForJobArrays = iCalculateTaskIDGroupsForJobArrays(taskIDsToSubmit, maxJobArraySize);
    
    schedulerIDs = cell(size(taskIDGroupsForJobArrays));
    for ii = 1:numel(taskIDGroupsForJobArrays)
        taskIDsInThisJobArray = taskIDGroupsForJobArrays{ii};
        numTasksInThisJobArray = numel(taskIDsInThisJobArray);
        firstTaskID = taskIDsInThisJobArray(1);
        lastTaskID = taskIDsInThisJobArray(end);
        
        environmentVariables = [commonEnvironmentVariables; ...
            {'PARALLEL_SERVER_TASK_ID_OFFSET', num2str(firstTaskID)}];
        
        if numTasksInThisJobArray == 1
            jobName = sprintf('Job%dTask%d', job.ID, firstTaskID);
        else
            jobName = sprintf('Job%dTasks%d-%d', job.ID, firstTaskID, lastTaskID);
        end
        
        schedulerID = parallel.cluster.generic.awsbatch.submitBatchJob( ...
            numTasksInThisJobArray, jobName, jobQueue, jobDefinition, ...
            remoteScriptName, environmentVariables(:,1), environmentVariables(:,2));
        
        if schedulerID == ""
            error('parallelexamples:GenericAWSBatch:FailedToParseSubmissionOutput', ...
                'Failed to parse the job identifier from the submission output: "%s"', ...
                cmdOut);
        end
        
        if numTasksInThisJobArray == 1
            schedulerIDs{ii} = schedulerID;
        else
            schedulerIDs{ii} = schedulerID + ":" + (0:(numTasksInThisJobArray - 1))';
        end
    end
    schedulerIDs = vertcat(schedulerIDs{:});
    
    % Set the task's schedulerIDs.
    set(tasksToSubmit, 'SchedulerID', schedulerIDs);
    
    % Store necessary information in the JobClusterData so that the outputs of
    % the job can be retrieved in the future.
    jobData = struct(...
        'FilesExistInS3', true, ...
        'S3Prefix', s3Prefix, ...
        'HasDownloadedOutputFilesFromS3', false, ...
        'TaskIDToLogStreamMap', containers.Map('KeyType', 'double', 'ValueType', 'char'));
    cluster.setJobClusterData(job, jobData);
catch err
    % Attempt to clean up any files left in S3 before rethrowing error.
    parallel.cluster.generic.awsbatch.deleteJobFilesFromS3(job, s3Bucket, s3Prefix);
    rethrow(err);
end
end

function taskIDGroupsForJobArrays = iCalculateTaskIDGroupsForJobArrays(taskIDsToSubmit, maxJobArraySize)
% Calculates the groups of task IDs to be submitted as job arrays

% We can only put tasks with sequential IDs into the same job array
% (the taskIDs will not be sequential if any tasks have been cancelled or
% deleted). We also need to ensure that each job array is smaller than
% maxJobArraySize.  So we first identify the sequential task IDs, and then
% split them apart into chunks of maxJobArraySize.

% The end of a range of sequential task IDs can be identified where
% diff(taskIDsToSubmit) > 1. We also know the last taskID to be the end of
% a range.
isEndOfSequentialTaskIDs = [diff(taskIDsToSubmit) > 1; true];
endOfSequentialTaskIDsIdx = find(isEndOfSequentialTaskIDs);

% The difference between indices give the number of tasks in each range.
numTasksInEachRange = [endOfSequentialTaskIDsIdx(1); diff(endOfSequentialTaskIDsIdx)];

% The number of tasks in each job array must be less than maxJobArraySize.
jobArraySizes = arrayfun(@(x) iCalculateJobArraySizes(x, maxJobArraySize), numTasksInEachRange, 'UniformOutput', false);
jobArraySizes = [jobArraySizes{:}];
taskIDGroupsForJobArrays = mat2cell(taskIDsToSubmit, jobArraySizes);
end

function jobArraySizes = iCalculateJobArraySizes(numTasksInRange, maxJobArraySize)
numJobArrays = ceil(numTasksInRange./maxJobArraySize);
jobArraySizes = repmat(maxJobArraySize, 1, numJobArrays);
remainder = mod(numTasksInRange, maxJobArraySize);
if remainder > 0
    jobArraySizes(end) = remainder;
end
end
