function downloadCloudWatchLog(logGroup, logStream, filePath)
%DOWNLOADCLOUDWATCHLOG Download a log stream from AWS CloudWatch.
%   downloadCloudWatchLog(LOGGROUP, LOGSTREAM, FILEPATH) downloads from AWS
%   CloudWatch the log stream named LOGSTREAM in the log group named
%   LOGGROUP to the path specified by FILEPATH.

%   Copyright 2019-2020 The MathWorks, Inc.

narginchk(3, 3);
validateattributes(logGroup,  {'string', 'char'}, {'scalartext'}, 'parallel.cluster.generic.awsbatch.downloadCloudWatchLog', 'logGroup');
validateattributes(logStream, {'string', 'char'}, {'scalartext'}, 'parallel.cluster.generic.awsbatch.downloadCloudWatchLog', 'logStream');
validateattributes(filePath,  {'string', 'char'}, {'scalartext'}, 'parallel.cluster.generic.awsbatch.downloadCloudWatchLog', 'filePath');

% Convert all inputs to Strings.
[logGroup, logStream, filePath] = convertCharsToStrings(logGroup, logStream, filePath);

parallel.internal.supportpackages.awsbatch.initAwsMexFunctionsIfNecessary();
logString = parallel.internal.supportpackages.awsbatch.getCloudWatchLog(logGroup, logStream);

% The log text may contain '\' and '%', so escape these characters.  We
% also need to replace any carriage returns with new lines so that the log
% is displayed correctly.
logString = replace(logString, ["\", "%", sprintf("\r")], ["\\", "%%", newline]);

[fileID, errorMessage] = fopen(filePath, 'wt');
if fileID < 0
    error(message('parallel_supportpackages:generic_scheduler:AWSBatchWriteLogFileFailed', ...
        filePath, errorMessage));
end
closer = onCleanup(@() fclose(fileID));
fprintf(fileID, logString);