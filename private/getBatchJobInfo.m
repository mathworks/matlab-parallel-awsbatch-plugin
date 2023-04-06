function outputTable = getBatchJobInfo(job)
%GETBATCHJOBINFO Get the status and log stream name from AWS Batch for all of the tasks in a job.
%   [TABLE] = getBatchJobInfo(JOB) returns a table containing the following
%   string array variables:
%       TaskID        - The ID of tasks from the input job.
%       Status        - The status as reported by AWS Batch for a task's
%                       corresponding AWS Batch job. If AWS Batch does not
%                       provide a state for a job, Status will be set to
%                       "UNKNOWN". Note that "UNKNOWN" is not a state
%                       defined by AWS.
%       LogStreamName - The log stream name in AWS CloudWatch logs for a
%                       task's corresponding AWS Batch job.  If AWS Batch
%                       does not provide a log stream name for a job,
%                       LogStreamName will be set to "".
%
%   Note that AWS only returns information for an AWS Batch job in the
%   SUCCEEDED or FAILED state for 24 hours.  After this time, no
%   information can be gathered, and so this function will return the job's
%   Status as "UNKNOWN" and its LogStreamName as "" in the output table.
%
%   getBatchJobInfo does not provide information for any of the input job's
%   tasks that do not have a SchedulerID set, as it is assumed that these
%   tasks have not been submitted to AWS Batch.

%   Copyright 2019-2023 The MathWorks, Inc.

narginchk(1, 1);
validateattributes(job, {'parallel.job.CJSIndependentJob'}, {'scalar'}, ...
    'getBatchJobInfo', 'job');

variableNames = {'TaskID', 'SchedulerID', 'Status', 'LogStreamName'};

% Filter out the tasks which don't have a schedulerID.
tasks = job.Tasks;
schedulerIDs = convertCharsToStrings(get(tasks, 'SchedulerID'));
schedulerIDExists = (schedulerIDs ~= "");
tasksWithSchedulerIDs = tasks(schedulerIDExists);
schedulerIDs = schedulerIDs(schedulerIDExists);

% Get information from AWS Batch
cmd = sprintf('aws batch describe-jobs --no-cli-pager --output json --jobs %s', strjoin(schedulerIDs));
[exitCode, out] = system(cmd);
if exitCode ~= 0
    error('parallelexamples:GenericAWSBatch:GetJobInfoFailed', ...
        'Failed to get AWS Batch job information.\n%s', out);
end
jobInfo = jsondecode(out);
outputSchedulerIDs = {jobInfo.jobs.jobId}.';
statuses = {jobInfo.jobs.status}.';
logStreamNames = cellfun(@(container) container.logStreamName, {jobInfo.jobs.container}, ...
    'UniformOutput', false, ...
    'ErrorHandler', @(varargin) '').';

% Determine which SchedulerIDs AWS did not return information on.
missingSchedulerIDs = setdiff(schedulerIDs, outputSchedulerIDs, 'rows');

% Immediately after submission, AWS may not provide information on child
% jobs in job arrays, but will return information on the parent job. We
% need to identify the child jobs so we can query AWS again with their
% parent IDs.  For non array jobs, we have to set the status to "UNKNOWN"
% and the LogStreamName to "".
isMissingChildJob = contains(missingSchedulerIDs, ':');
missingChildJobIDs = missingSchedulerIDs(isMissingChildJob);
missingNonArrayJobIDs = missingSchedulerIDs(~isMissingChildJob);

% For non array jobs, we have to set the status to "UNKNOWN" and the
% LogStreamName to "".
outputSchedulerIDs = [outputSchedulerIDs; missingNonArrayJobIDs];
statuses = [statuses; repmat("UNKNOWN", size(missingNonArrayJobIDs))];
logStreamNames = [logStreamNames; repmat("", size(missingNonArrayJobIDs))];

if ~isempty(missingChildJobIDs)
    % Set the child jobs statuses to "UNKNOWN" and log stream names to ""
    % for now. We will update these values if we find out more information
    % using the parent job ID.
    childJobStatuses = repmat("UNKNOWN", size(missingChildJobIDs));
    childJobLogStreamNames = repmat("", size(missingChildJobIDs));
    
    parentJobIDs = split(missingChildJobIDs, ':');
    parentJobIDs = unique(parentJobIDs(:, 1));
    [outputParentIDs, parentStatuses] = parallel.internal.supportpackages.awsbatch.getBatchJobInfo(parentJobIDs);
    
    for ii = 1:numel(outputParentIDs)
        isChildJobOfParentID = startsWith(missingChildJobIDs, outputParentIDs(ii));
        childJobStatuses(isChildJobOfParentID) = parentStatuses(ii);
    end
    
    outputSchedulerIDs = [outputSchedulerIDs; missingChildJobIDs];
    statuses = [statuses; childJobStatuses];
    logStreamNames = [logStreamNames; childJobLogStreamNames];
end

% Create a table containing SchedulerID, Status and LogStreamName.
outputTable = table(outputSchedulerIDs, statuses, logStreamNames, 'VariableNames', variableNames(2:4));

% Create a table containing TaskID and SchedulerID.
taskIDs = cell2mat(get(tasksWithSchedulerIDs, {'ID'}));
taskIDtoSchedulerIDTable = table(taskIDs, schedulerIDs, 'VariableNames', variableNames(1:2));

% By joining the two tables, we get a table that maps a task's ID to its
% status and log stream name (and vice versa).
outputTable = join(taskIDtoSchedulerIDTable, outputTable);

% Remove SchedulerID from the output table.
outputTable = removevars(outputTable, {'SchedulerID'});

end
