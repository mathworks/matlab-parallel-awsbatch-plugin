function initAwsMexFunctionsIfNecessary()
%INITAWSMEXFUNCTIONSIFNECESSARY Initializes the MEX functions that call the AWS SDK
%   This function ensures that:
%     1. AWS::InitAPI has been called.
%     2. The MEX functions can find the AWS SDK dynamic libraries (Windows
%        only)

%   Copyright 2020 The MathWorks, Inc.

parallel.internal.supportpackages.awsbatch.initAwsApiIfNecessary();
parallel.internal.supportpackages.awsbatch.addAwsDynamicLibsLocationToSystemPathIfNecessary();
end