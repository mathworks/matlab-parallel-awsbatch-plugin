function schedulerID = submitBatchJob(arraySize, jobName, jobQueue, jobDefinition, command, environmentVariableNames, environmentVariableValues)
%SUBMITBATCHJOB Submit job to AWS Batch.
%   SCHEDULERID = submitBatchJob(ARRAYSIZE, JOBNAME, JOBQUEUE, ...
%   JOBDEFINITION, COMMAND, ENVIRONMENTVARIABLENAMES, ...
%   ENVIRONMENTVARIABLEVALUES) submits to AWS Batch a job of size ARRAYSIZE
%   with name JOBNAME and job definition JOBDEFINITION, to the AWS Batch
%   job queue JOBQUEUE. The command COMMAND is passed to the container that
%   runs the AWS Batch job. The job runs with the environment variable
%   names ENVIRONMENTVARIABLENAMES and values ENVIRONMENTVARIABLEVALUES.
%   The function returns AWS Batch job ID as a string scalar. If
%   ARRAYSIZE == 1, then submitBatchJob submits a non-array job.
%
%   For information about AWS Batch job queues, job definitions, array jobs
%   and how the command passed to the container that runs the AWS Batch job
%   is used, see the AWS Batch documentation.

%   Copyright 2019-2020 The MathWorks, Inc.

validateattributes(arraySize, {'numeric'}, {'scalar', 'integer', '>', 0}, ...
    'parallel.cluster.generic.awsbatch.submitBatchJob', 'numTasks');
validateattributes(jobName, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.submitBatchJob', 'jobName');
validateattributes(jobQueue, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.submitBatchJob', 'jobQueue');
validateattributes(jobDefinition, {'string', 'char'}, {'scalartext'},...
    'parallel.cluster.generic.awsbatch.submitBatchJob', 'JobDefinition');
validateattributes(command, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.submitBatchJob', 'command');

% ValidateAttributes does not provide a way to check for cellstrings so we
% have to check the types of environmentVariableNames and
% environmentVariableValues manually.
iValidateStringOrCellStrVector(environmentVariableNames,  'environmentVariableNames');
iValidateStringOrCellStrVector(environmentVariableValues, 'environmentVariableValues');

% Check that environmentVariableNames and environmentVariableValues have
% the same number of elements.
if numel(environmentVariableNames) ~= numel(environmentVariableValues)
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchInputsMustBeSameSize', 'environmentVariableNames', 'environmentVariableValues'));
end

% Convert all text inputs to Strings.
[jobName, jobQueue, jobDefinition, command, environmentVariableNames, environmentVariableValues] =  ...
    convertCharsToStrings(jobName, jobQueue, jobDefinition, command, environmentVariableNames, environmentVariableValues);

parallel.internal.supportpackages.awsbatch.initAwsMexFunctionsIfNecessary();
schedulerID = parallel.internal.supportpackages.awsbatch.submitBatchJob(...
    arraySize, jobName, jobQueue, jobDefinition, command, ...
    environmentVariableNames, environmentVariableValues);
end

function iValidateStringOrCellStrVector(argument, argumentName)
if ~isstring(argument) && ~iscellstr(argument)
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchExpectedStringOrCellStr', argumentName, class(argument)));
end
if ~isempty(argument)
    validateattributes(argument,  {'string', 'cell'}, {'vector'}, 'parallel.cluster.generic.awsbatch.submitBatchJob', argumentName);
end
end
