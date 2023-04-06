function deleteBatchJob(jobID)
%DELETEBATCHJOB Terminate a job in AWS Batch.
%   deleteBatchJob(JOBID) terminates the AWS Batch job with ID jobID.

%   Copyright 2019-2023 The MathWorks, Inc.

narginchk(1, 1);
validateattributes(jobID, {'string', 'char'}, {'scalartext'}, ...
    'deleteBatchJob', 'jobID');

cmd = sprintf('aws batch terminate-job --no-cli-pager --output json --job-id %s --reason "%s"', ...
    jobID, 'Deleted from MATLAB client.');
[exitCode, out] = system(cmd);
if exitCode ~= 0
    error('parallelexamples:GenericAWSBatch:TerminateJobFailed', ...
        'Failed to terminate job %d in AWS Batch.\n%s', ...
        jobId, out);
end

end
