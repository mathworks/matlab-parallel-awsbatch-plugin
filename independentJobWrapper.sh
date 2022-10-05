#!/bin/sh
# This wrapper script is intended to support independent execution.
#
# This script uses the following environment variables set by the submit MATLAB code:
# PARALLEL_SERVER_MATLAB_EXE  - the MATLAB executable to use
# PARALLEL_SERVER_MATLAB_ARGS - the MATLAB args to use

# Copyright 2019-2020 The MathWorks, Inc.

# If PARALLEL_SERVER_ environment variables are not set, assign any
# available values with form MDCE_ for backwards compatibility
PARALLEL_SERVER_MATLAB_EXE=${PARALLEL_SERVER_MATLAB_EXE:="${MDCE_MATLAB_EXE}"}
PARALLEL_SERVER_MATLAB_ARGS=${PARALLEL_SERVER_MATLAB_ARGS:="${MDCE_MATLAB_ARGS}"}

echo "Executing: ${PARALLEL_SERVER_MATLAB_EXE} ${PARALLEL_SERVER_MATLAB_ARGS}"
eval "${PARALLEL_SERVER_MATLAB_EXE}" ${PARALLEL_SERVER_MATLAB_ARGS}
EXIT_CODE=${?}
echo "Exiting with code: ${EXIT_CODE}"
exit ${EXIT_CODE}
