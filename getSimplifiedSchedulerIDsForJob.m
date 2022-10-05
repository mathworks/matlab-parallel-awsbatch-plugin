function schedulerIDs = getSimplifiedSchedulerIDsForJob(job)
%GETSIMPLIFIEDSCHEDULERIDSFORJOB Returns the smallest possible list of AWS Batch job IDs that describe the MATLAB job.
%
% SCHEDULERIDS = getSimplifiedSchedulerIDsForJob(JOB) returns the smallest
% possible list of AWS Batch job IDs that describe the MATLAB job JOB. AWS
% job IDs corresponding to a child job in a job array are converted to
% their parent job IDs, and then any duplicates are removed.

%   Copyright 2019 The MathWorks, Inc.

schedulerIDs = job.getTaskSchedulerIDs();

% Child jobs within a job array will have a schedulerID of the form
% <parent job ID>:<array index>.
schedulerIDs = regexprep(schedulerIDs, ':\d+', '');
schedulerIDs = unique(schedulerIDs, 'stable');
end
