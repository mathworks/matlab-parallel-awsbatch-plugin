function initAwsApiIfNecessary()
%INITAWSAPIIFNECESSARY Ensures that the AWS C++ SDK method AWS::InitAPI() has been called.
%   This method MUST be called before any of the Mex functions in this
%   directory.
%
%   The AWS C++ SDK documentation states that AWS::InitAPI must be called
%   before any other SDK methods, and must not be called again until a
%   corresponding AWS::ShutdownAPI call is made. MATLAB does not currently
%   have a mechanism for ensuring this. S3Provider was written with the
%   assumption that it was the only client of the AWS C++ SDK, and calls
%   AWS::InitAPI the first time an operation on S3 occurs, but never calls
%   AWS::ShutdownAPI. This means that the Mex functions themselves cannot
%   call AWS::InitAPI themselves in case it has already been called.
%
%   Since there is no way to detect whether AWS::InitAPI has been called,
%   this method performs a minimal S3 operation the first time it is run
%   in a MATLAB session.
%
%   TODO(g2007702): Provide a way to for multiple clients to call
%   AWS::InitAPI.

%   Copyright 2019 The MathWorks, Inc.

persistent initialised
mlock
if isempty(initialised)
    try
        % Deliberately use an invalid bucket name (< 3 characters long) so
        % that we trigger the AWS initialisation without actually
        % communicating with any valid bucket.
        isfolder('s3://mw/');
    catch
        % We do not want to error out, so catch and ignore any errors.
    end
    initialised = true;
end
end

