function schedulerID = submitBatchJob(arraySize, jobName, jobQueue, jobDefinition, command, environmentVariables)
%SUBMITBATCHJOB Submit job to AWS Batch.
%   SCHEDULERID = submitBatchJob(ARRAYSIZE, JOBNAME, JOBQUEUE, ...
%   JOBDEFINITION, COMMAND, ENVIRONMENTVARIABLENAMES, ...
%   ENVIRONMENTVARIABLEVALUES) submits to AWS Batch a job of size ARRAYSIZE
%   with name JOBNAME and job definition JOBDEFINITION, to the AWS Batch
%   job queue JOBQUEUE. The command COMMAND is passed to the container that
%   runs the AWS Batch job. The job runs with the environment variables
%   specified by ENVIRONMENTVARIABLES. The function returns AWS Batch job
%   ID as a string scalar. If ARRAYSIZE == 1, then submitBatchJob submits a
%   non-array job.
%
%   For information about AWS Batch job queues, job definitions, array jobs
%   and how the command passed to the container that runs the AWS Batch job
%   is used, see the AWS Batch documentation.

%   Copyright 2019-2023 The MathWorks, Inc.

narginchk(6, 6);
validateattributes(arraySize, {'numeric'}, {'scalar', 'integer', '>', 0}, ...
    'submitBatchJob', 'numTasks');
validateattributes(jobName, {'string', 'char'}, {'scalartext'}, ...
    'submitBatchJob', 'jobName');
validateattributes(jobQueue, {'string', 'char'}, {'scalartext'}, ...
    'submitBatchJob', 'jobQueue');
validateattributes(jobDefinition, {'string', 'char'}, {'scalartext'},...
    'submitBatchJob', 'JobDefinition');
validateattributes(command, {'string', 'char'}, {'scalartext'}, ...
    'submitBatchJob', 'command');
iValidateEnvironmentVariables(environmentVariables,  'environmentVariables');

% Construct the value for the --container-overrides option in json format
environmentArray = iConvertEnvironmentVariablesToStructArray(environmentVariables);
containerOverrideStruct = struct('command', {{command}}, 'environment', environmentArray);
containerOverrides = jsonencode(containerOverrideStruct);
containerOverrides = iEscapeJSONQuotes(containerOverrides);

% Construct the command to run
cmd = sprintf(['aws batch submit-job --no-cli-pager --output json ' ...
    '--job-name %s --job-queue %s ' ...
    '--job-definition %s --container-overrides %s'], ...
    jobName, jobQueue, jobDefinition, containerOverrides);
if arraySize > 1
    cmd = sprintf('%s --array-properties size=%d', cmd, arraySize);
end

% Run the command
[exitCode, out] = system(cmd);
if exitCode ~= 0
    error('parallelexamples:GenericAWSBatch:SubmitJobFailed', ...
        'Failed to submit job to AWS Batch with job name ''%s'', job queue ''%s'' and job definition ''%s''.\n%s', ...
        jobName, jobQueue, jobDefinition, out);
end

% Extract the job's ID
jsonOut = jsondecode(out);
if ~isfield(jsonOut, 'jobId')
    error('parallelexamples:GenericAWSBatch:FailedToParseSubmissionOutput', ...
        'Failed to parse the job identifier from the submission output: "%s"', ...
        out);
end
schedulerID = jsonOut.jobId;

end

function iValidateEnvironmentVariables(argument, argumentName)
if ~isstring(argument) && ~iscellstr(argument)
    error('parallelexamples:GenericAWSBatch:ExpectedStringOrCellStr', ...
        'Input %s must be a string array or a cell array of character vectors. Instead its type was %s.', ...
        argumentName, class(argument));
end
if ~isempty(argument)
    validateattributes(argument,  {'string', 'cell'}, {'ncols', 2}, 'submitBatchJob', argumentName);
end
end

function varArray = iConvertEnvironmentVariablesToStructArray(environmentVariables)
% submit-job requires the environment to be specified as an array with
% fields 'name' and 'value'
names = environmentVariables(:, 1);
values = environmentVariables(:, 2);
varArray = cellfun( ...
    @(name, value) struct('name', name, 'value', value), ...
    names, values);
end

function str = iEscapeJSONQuotes(str)
if ispc
    % Escape double-quotes with a backslash then surround with unescaped
    % double-quotes
    str = ['"' strrep(str, '"', '\"') '"'];
else
    % Surround with single-quotes
    str = ['''' str ''''];
end
end
