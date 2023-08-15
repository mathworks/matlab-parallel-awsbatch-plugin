# Parallel Computing Toolbox plugin for MATLAB Parallel Server with AWS Batch

[![View Parallel Computing Toolbox Plugin for AWS Batch on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/127394-parallel-computing-toolbox-plugin-for-aws-batch)

MATLAB&reg; Parallel Computing Toolbox&trade; provides the `Generic` cluster type for submitting MATLAB jobs to a cluster running a third-party scheduler.
`Generic` uses a set of plugin scripts to define how your machine running MATLAB or Simulink&reg; communicates with your scheduler.
You can customize the plugin scripts to configure how MATLAB interacts with the scheduler to best suit your cluster's setup and to support custom submission options.

This repository contains MATLAB code files and shell scripts that you can use to submit jobs from a MATLAB or Simulink session running on Windows&reg;, Linux&reg;, or macOS to AWS Batch.

## Products Required

- [MATLAB](https://www.mathworks.com/products/matlab.html) and [Parallel Computing Toolbox](https://www.mathworks.com/products/parallel-computing.html), release R2020b or newer, installed on your computer.
For more information about installing MATLAB and toolboxes on your computer, see [Installation and Licensing](https://www.mathworks.com/help/install/index.html).
- [AWS Command Line Interface tool](https://aws.amazon.com/cli) installed and configured on your computer.

## Usage Notes

MATLAB Parallel Server with AWS Batch does not support communicating jobs.
To learn more about communicating jobs, see [Program Communicating Jobs](https://www.mathworks.com/help/parallel-computing/introduction.html).

## Setup Instructions

Before proceeding, ensure that the above required products are installed.

### Download or Clone this Repository

To download a zip file of this repository, at the top of this repository page, select **Code > Download ZIP**.
Alternatively, to clone this repository to your computer with git installed, run the following command on your operating system's command line:
```
git clone https://github.com/mathworks/matlab-parallel-aws-batch-plugin
```
You can execute a system command from the MATLAB command line by adding a `!` before the command.

### Launch the Reference Architecture in AWS Batch

The "MATLAB Parallel Server with AWS Batch" reference architecture must be running in your AWS account.
If you are an end user, contact your administrator to see if the reference architecture has already been launched.
If you need to launch the reference architecture yourself, see the GitHub repository for [MATLAB Parallel Server with AWS Batch](https://github.com/mathworks-ref-arch/matlab-parallel-server-with-aws-batch).

### Configure Your AWS Credentials

Configure your machine with your AWS Credentials using the [AWS Command Line Interface tool](https://aws.amazon.com/cli/).
Alternatively, you can set up your credentials by setting the following environment variables:

**Environment variable** | **Description**
-------------------------| ---------------
AWS_ACCESS_KEY_ID        | Specifies an AWS access key associated with an IAM (Identity and Access Management) user or role.
AWS_SECRET_ACCESS_KEY    | Specifies the secret key associated with the access key. This is essentially the "password" for the access key.
AWS_SESSION_TOKEN        | Specifies the session token value. Required if you are using temporary security credentials.
AWS_DEFAULT_REGION       | Specifies the AWS Region to send the request to. The value of this environment variable is typically determined automatically but you may wish to set it manually.

If you do not know your AWS Credentials, contact your administrator.
You can set the environment variables in your current MATLAB session using `setenv` as follows:
```matlab
setenv('AWS_ACCESS_KEY_ID', 'YOUR_AWS_ACCESS_KEY_ID');
setenv('AWS_SECRET_ACCESS_KEY', 'YOUR_AWS_SECRET_ACCESS_KEY');
setenv('AWS_SESSION_TOKEN', 'YOUR_AWS_SESSION_TOKEN');
setenv('AWS_DEFAULT_REGION', 'YOUR_AWS_DEFAULT_REGION');
```

### Cluster Discovery

Since version R2023a, MATLAB can discover clusters running third-party schedulers such as AWS Batch.
As a cluster admin, you can create a configuration file that describes how to configure the Parallel Computing Toolbox on the user's machine to submit MATLAB jobs to the cluster.
The cluster configuration file is a plain text file with the extension `.conf` containing key-value pairs that describe the cluster configuration information.
The MATLAB client will use the cluster configuration file to create a cluster profile for the user who discovers the cluster.
Therefore, users will not need to follow the instructions in the sections below.
You can find an example of a cluster configuration file in [discover/example.conf](discover/example.conf).
For full details on how to make a cluster running a third-party scheduler discoverable, see the documentation for [Configure for Third-Party Scheduler Cluster Discovery](https://www.mathworks.com/help/matlab-parallel-server/configure-for-cluster-discovery.html).

### Create a Cluster Profile in MATLAB

You can create a cluster profile by using either the Cluster Profile Manager or the MATLAB command line.

To open the Cluster Profile Manager, on the **Home** tab, in the **Environment** section, select **Parallel > Create and Manage Clusters**.
Within the Cluster Profile Manager, select **Add Cluster Profile > Generic** from the menu to create a new `Generic` cluster profile.

Alternatively, for a command line workflow without using graphical user interfaces, create a new `Generic` cluster object by running:
```matlab
c = parallel.cluster.Generic;
```

### Configure Cluster Properties

The table below gives the minimum properties required for `Generic` to work correctly.
For a full list of cluster properties, see the documentation for [`parallel.Cluster`](https://www.mathworks.com/help/parallel-computing/parallel.cluster.html).

**Property**          | **Value**
----------------------|----------------
JobStorageLocation    | Where job data is stored by your machine.
NumWorkers            | Number of workers your license allows.
ClusterMatlabRoot     | '/usr/local/matlab'
OperatingSystem       | 'unix'
HasSharedFilesystem   | false
PluginScriptsLocation | Full path to the folder containing this file.

In the Cluster Profile Manager, set each property value in the boxes provided.
Alternatively, at the command line, set each property on the cluster object using dot notation:
```matlab
c.JobStorageLocation = 'C:\MatlabJobs';
% etc.
```

At the command line, you can also set properties at the same time you create the `Generic` cluster object, by specifying name-value pairs in the constructor:
```matlab
c = parallel.cluster.Generic( ...
    'JobStorageLocation', 'C:\MatlabJobs', ...
    'NumWorkers', 20, ...
    'ClusterMatlabRoot', '/usr/local/matlab', ...
    'OperatingSystem', 'unix', ...
    'HasSharedFileSystem', false, ...
    'PluginScriptsLocation', 'C:\MatlabAwsBatchPlugin\shared');
```

### Configure AdditionalProperties

You can use `AdditionalProperties` as a way of modifying the behaviour of `Generic` without having to edit the plugin scripts.
By modifying the plugins, you can add support for your own custom `AdditionalProperties`.
The following `AdditionalProperties` are required:

**Property Name**        | **Description**
-------------------------|----------------
IndependentJobDefinition | The AWS Batch job definition for independent jobs.
JobQueue                 | The AWS Batch job queue of the cluster.
S3Bucket                 | The Amazon S3 bucket for data transfer between the client and workers.

The following additional property is optional:

**Property Name** | **Description**
------------------|----------------
LicenseServer     | The port and hostname of a machine running a Network License Manager in the format port@hostname.

If you have launched the "MATLAB Parallel Server with AWS Batch" reference architecture yourself, this information can be found in the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/) by navigating to the output view of the stack.
If you are an end-user, contact your administrator for this information.

In the Cluster Profile Manager, add new `AdditionalProperties` by clicking **Add** under the table of `AdditionalProperties`.
On the command line, use dot notation to add new fields:
```matlab
c.AdditionalProperties.IndependentJobDefinition = '<Job definition>';
```

### Save Your New Profile

In the Cluster Profile Manager, click **Done**.
If creating the cluster on the command line, run:
```matlab
saveAsProfile(c, "myAwsBatchCluster");
```
Your cluster profile is now ready to use.

### Validate the Cluster Profile

Cluster validation submits one of each type of job to test the cluster profile has been configured correctly.
In the Cluster Profile Manager, click the **Validate** button.
The Cluster connection test (parcluster) and Job test (createJob) stages should pass successfully.
The remaining validation stages will not pass as communicating jobs are not supported.
If you make a change to a cluster profile, you can rerun cluster validation to ensure there are no errors.
You do not need to validate each time you use the profile or each time you start MATLAB.

## Examples

First create a cluster object using your profile:
```matlab
c = parcluster("myAwsBatchCluster")
```

### Submit Work for Batch Processing

The `batch` command runs a MATLAB script or function on a worker on the cluster.
For more information about batch processing, see the documentation for the [batch command](https://www.mathworks.com/help/parallel-computing/batch.html).

```matlab
% Create and submit a job to the cluster
job = batch( ...
    c, ... % cluster object created using parcluster
    @sqrt, ... % function/script to run
    1, ... % number of output arguments
    {[64 100]}); % input arguments

% Your MATLAB session is now available to do other work, such
% as create and submit more jobs to the cluster. You can also
% shut down your MATLAB session and come back later - the work
% will continue running on the cluster. Once you've recreated
% the cluster object using parcluster, you can view existing
% jobs using the Jobs property on the cluster object.

% Wait for the job to complete. If the job is already complete,
% this will return immediately.
wait(job);

% Retrieve the output arguments for each task. For this example,
% results will be a 1x1 cell array containing the vector [8 10].
results = fetchOutputs(job)
```

## License

The license is available in the [license.txt](license.txt) file in this repository.

## Community Support

[MATLAB Central](https://www.mathworks.com/matlabcentral)

## Technical Support

If you require assistance or have a request for additional features or capabilities, contact MathWorks Technical Support at [https://www.mathworks.com/support/contact_us.html](https://www.mathworks.com/support/contact_us.html).

Copyright 2022-2023 The MathWorks, Inc.
