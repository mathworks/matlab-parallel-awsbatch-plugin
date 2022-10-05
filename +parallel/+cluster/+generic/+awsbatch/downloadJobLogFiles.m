function downloadJobLogFiles(job, taskIDs, logStreams)
%DOWNLOADJOBLOGFILES Downloads log files for a job that ran on MATLAB Parallel Server with AWS Batch.
%   downloadJobLogFiles(JOB, TASKIDs, LOGSTREAMS) downloads from AWS CLOUD
%   WATCH the log files for the tasks in JOB. The logs for tasks with IDs
%   specified in TASKIDs are downloaded from the log streams specified in
%   LOGSTREAMS to the JobStorageLocation.

%   Copyright 2019 The MathWorks, Inc.

validateattributes(job, {'parallel.job.CJSIndependentJob'}, {'scalar'}, ...
    'parallel.cluster.generic.awsbatch.downloadJobLogFiles', 'job');
if ~isempty(taskIDs)
    validateattributes(taskIDs, {'double'}, {'vector'}, ...
        'parallel.cluster.generic.awsbatch.downloadJobLogFiles', 'taskIDs');
end
% ValidateAttributes does not provide a way to check for cellstrings so we
% have to check the types of logStreamNames  manually.
iValidateStringOrCellStrVector(logStreams,  'logStreams');

% Check that taskIDs and logStreamNames have the same number of elements.
if numel(taskIDs) ~= numel(logStreams)
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchInputsMustBeSameSize', 'taskIDs', 'logStreams'));
end

logStreams = convertCharsToStrings(logStreams);

jobStorageLocation = job.Parent.JobStorageLocation;
jobFilesInfo = job.Parent.pGetJobFilesInfo(job);
taskFilesDirectoryName = jobFilesInfo.TaskFiles{:};

logFiles = fullfile(jobStorageLocation, taskFilesDirectoryName, "Task" + taskIDs + ".log");
logGroup = "/aws/batch/job";
for ii = 1:numel(logFiles)
    try
        parallel.internal.supportpackages.awsbatch.downloadCloudWatchLog(logGroup, logStreams(ii), logFiles(ii));
    catch err
        parallel.internal.warningNoBackTrace(message(...
            'parallel_supportpackages:generic_scheduler:AWSBatchDownloadLogFilesFailed', ...
            taskIDs(ii), job.ID, err.message));
    end
end
end

function iValidateStringOrCellStrVector(argument, argumentName)
if ~isstring(argument) && ~iscellstr(argument)
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchExpectedStringOrCellStr', argumentName, class(argument)));
end
if ~isempty(argument)
    validateattributes(argument,  {'string', 'cell'}, {'vector'}, 'parallel.cluster.generic.awsbatch.downloadJobLogFiles', argumentName);
end
end