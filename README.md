# Platform Connectivity

[![Build Status](https://dev.azure.com/frasermolyneux/Personal-Public/_apis/build/status/platform-connectivity.OnePipeline?repoName=frasermolyneux%2Fplatform-connectivity&branchName=main)](https://dev.azure.com/frasermolyneux/Personal-Public/_build/latest?definitionId=173&repoName=frasermolyneux%2Fplatform-connectivity&branchName=main)

## Overview

This repository contains the resource configuration and associated Azure DevOps pipelines for the connectivity related resources for the MX landing zones. These are strategic resources similar to the [frasermolyneux/platform-strategic-services](https://github.com/frasermolyneux/platform-strategic-services), however have been kept separate as deployed to different subscriptions.

---

## Related Projects

* [frasermolyneux/azure-landing-zones](https://github.com/frasermolyneux/azure-landing-zones) - The deploy service principal is managed by this project, as is the workload subscription.

---

## Solution

The solution will deploy the following resources:

* DNS Zones for the MX platform
* Azure Front Door

---

## Azure Pipelines

The `one-pipeline` is within the `.azure-pipelines` folder and output is visible on the [frasermolyneux/Personal-Public](https://dev.azure.com/frasermolyneux/Personal-Public/_build?definitionId=173) Azure DevOps project.

---

## Contributing

Please read the [contributing](CONTRIBUTING.md) guidance; this is a learning and development project.

---

## Security

Please read the [security](SECURITY.md) guidance; I am always open to security feedback through email or opening an issue.
