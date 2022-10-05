function deleteBatchJob(jobID)
%DELETEBATCHJOB Terminate a job in AWS Batch.
%   deleteBatchJob(JOBID) terminates the AWS Batch job with ID jobID.

%   Copyright 2019-2020 The MathWorks, Inc.

narginchk(1, 1);
validateattributes(jobID, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.deleteBatchJob', 'jobID');
jobID = convertCharsToStrings(jobID);
parallel.internal.supportpackages.awsbatch.initAwsMexFunctionsIfNecessary();
parallel.internal.supportpackages.awsbatch.deleteBatchJob(jobID);