function communicatingSubmitFcn(~, ~, ~)
%COMMUNICATINGSUBMITFCN MATLAB Parallel Server with AWS Batch does not support communicating jobs.
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you submit a communicating job.
%
% MATLAB Parallel Server with AWS Batch does not support communicating
% jobs.  This function will error.

% Copyright 2019-2022 The MathWorks, Inc.

error('parallelexamples:GenericAWSBatch:CommunicatingJobsNotSupported', ...
    'MATLAB Parallel Server with AWS Batch does not support communicating jobs.')

end
