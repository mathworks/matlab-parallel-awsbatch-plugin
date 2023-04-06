function downloadJobLogFiles(job, taskIDs, logStreams)
%DOWNLOADJOBLOGFILES Downloads log files for a job that ran on MATLAB Parallel Server with AWS Batch.
%   downloadJobLogFiles(JOB, TASKIDs, LOGSTREAMS) downloads from AWS CLOUD
%   WATCH the log files for the tasks in JOB. The logs for tasks with IDs
%   specified in TASKIDs are downloaded from the log streams specified in
%   LOGSTREAMS to the JobStorageLocation.

%   Copyright 2019-2023 The MathWorks, Inc.

validateattributes(job, {'parallel.job.CJSIndependentJob'}, {'scalar'}, ...
    'downloadJobLogFiles', 'job');
if ~isempty(taskIDs)
    validateattributes(taskIDs, {'double'}, {'vector'}, ...
        'downloadJobLogFiles', 'taskIDs');
end
% ValidateAttributes does not provide a way to check for cellstrings so we
% have to check the types of logStreamNames  manually.
iValidateStringOrCellStrVector(logStreams,  'logStreams');

% Check that taskIDs and logStreamNames have the same number of elements.
if numel(taskIDs) ~= numel(logStreams)
    error('parallelexamples:GenericAWSBatch:InputsMustBeSameSize', ...
        'Inputs taskIDs and logStreams must have the same number of elements');
end

logStreams = convertCharsToStrings(logStreams);

jobStorageLocation = job.Parent.JobStorageLocation;
jobFilesInfo = job.Parent.pGetJobFilesInfo(job);
taskFilesDirectoryName = jobFilesInfo.TaskFiles{:};

logFiles = fullfile(jobStorageLocation, taskFilesDirectoryName, "Task" + taskIDs + ".log");
logGroup = "/aws/batch/job";
for ii = 1:numel(logFiles)
    try
        iDownloadCloudWatchLog(logGroup, logStreams(ii), logFiles(ii));
    catch err
        warning('parallelexamples:GenericAWSBatch:DownloadLogFilesFailed', ...
            'Failed to download log file for task %d in job %s.\n%s', ...
            taskIDs(ii), job.ID, err.message);
    end
end
end

function iDownloadCloudWatchLog(logGroup, logStream, filePath)

% Open log file
[fileID, errorMessage] = fopen(filePath, 'wt');
if fileID < 0
    error('parallelexamples:GenericAWSBatch:WriteLogFileFailed', ...
        'Failed to write AWS Cloud Watch log to ''%s''.\n%s', ...
        filePath, errorMessage);
end
closer = onCleanup(@() fclose(fileID));

% Obtain the log from AWS
cmd = sprintf('aws logs get-log-events --no-cli-pager --output json --log-group-name %s --log-stream-name %s', ...
    logGroup, logStream);
[exitCode, out] = system(cmd);
if exitCode ~= 0
    error('parallelexamples:GenericAWSBatch:GetCloudWatchLogFailed', ...
        'Failed to get log stream ''%s'' in log group ''%s'' from AWS Cloud Watch logs.\n%s', ...
        logStream, logGroup, out);
end
log = jsondecode(out);

% Output each line
arrayfun(@(e) iPrintEventMessage(fileID, e), log.events);

end

function iPrintEventMessage(fid, event)
% Replace any carriage returns with plain line feeds so that the log is
% displayed correctly.
message = replace(event.message, sprintf("\r\n"), newline);
fprintf(fid, '%s\n', message);
end

function iValidateStringOrCellStrVector(argument, argumentName)
if ~isstring(argument) && ~iscellstr(argument)
    error('parallelexamples:GenericAWSBatch:ExpectedStringOrCellStr', ...
        'Input %s must be a string array or a cell array of character vectors. Instead its type was %s.', ...
        argumentName, class(argument));
end
if ~isempty(argument)
    validateattributes(argument,  {'string', 'cell'}, {'vector'}, 'downloadJobLogFiles', argumentName);
end
end
