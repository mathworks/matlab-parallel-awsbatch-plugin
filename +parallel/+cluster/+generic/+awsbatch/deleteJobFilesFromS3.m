function deleteJobFilesFromS3(job, s3Bucket, s3Prefix)
%DELETEJOBFILESFROMS3 Delete from S3 the files for a job submitted to MATLAB Parallel Server with AWS Batch.
%   deleteJobFilesFromS3(JOB, S3BUCKET, S3PREFIX) deletes from S3 all of
%   JOB's files, which are located in the folder s3://S3BUCKET/S3PREFIX.

%   Copyright 2019 The MathWorks, Inc.

narginchk(3, 3);
validateattributes(job, {'parallel.job.CJSIndependentJob'}, {'scalar'}, ...
    'parallel.cluster.generic.awsbatch.deleteJobFilesFromS3', 'job');
validateattributes(s3Bucket, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.deleteJobFilesFromS3', 's3Bucket');
validateattributes(s3Prefix, {'string', 'char'}, {'scalartext'}, ...
    'parallel.cluster.generic.awsbatch.deleteJobFilesFromS3', 's3Prefix');

currFilename = mfilename;
dctSchedulerMessage(4, '%s: Deleting folder %s from S3 bucket %s for job %d.', ...
    currFilename, s3Prefix, s3Bucket, job.ID);
try
    rmdir("s3://" + s3Bucket + "/" + s3Prefix, "s");
catch err
    % Catch and throw the error so that the user cannot tell that we're
    % using rmdir from the error stack.
    dctSchedulerMessage(1, '%s: Failed to delete folder %s from S3 bucket %s for job %d.  Reason: %s', ...
        currFilename, s3Prefix, s3Bucket, job.ID, err.message);
    throw(err)
end