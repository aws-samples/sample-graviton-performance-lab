# Graviton and performance engineering

The goal of this lab is to provide *test automation*, *faster time to value* (moving from weeks to hours), and *reproducible results* grounded in sound performance engineering practices in the context of evaluating AWS Graviton (and related Amazon EC2 capabilities such as AWS Nitro).

We provide a test harness for running controlled experiments, reducing the cost of test runs via declarative templates and test automation that makes use of best practices such as Kubernetes, Karpenter, and ancillary tools (Argo Workflows). We want this lab to be benchmark-agnostic (by providing hooks for you to extend and customize) yet immediately useful (by eliminating the undifferentiated heavy-lift of building and maintaining test infrastructure).

The remainder of this `README` explains the process of provisioning test infrastructure in your AWS account, running a controlled experiment, and implementing a consistent evaluation rubric (RPS, latency, statistical tests) for driving instance upgrade or runtime refresh decisions.

While we write this lab for a general audience, we assume that you are a platform engineer with little to no background in performance engineering - you live and breathe Kubernetes and your work moves the needle for AppDev teams throughout your organization.

## Folders

### `terraform-infra`

This folder contains the Terraform manifests to set up the necessary AWS resources, including:

* VPC and Subnets
* EKS cluster
* ECR repository

### `k8s-resources`

This folder contains all the relevant Kubernetes resources, including:

* [Karpenter node pool](https://karpenter.sh/docs/concepts/nodepools/) definition
* Load testing server and client-side components

### `web-bookshop-app`

This folder contains the RESTful web application that will be used as the target for the load tests.

## Prerequisites

* Ensure you have the following tools installed: **[aws](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), [git](https://git-scm.com/downloads), [kubectl](https://kubernetes.io/docs/tasks/tools/), [terraform](https://developer.hashicorp.com/terraform/install)**
* You have admininstrative access to the AWS account
* A brand new VPC, subnet, EKS cluster, and ECR will be created (and terminated after completion)

Please speak with your AWS administrator if your requirements are different to that.

## Getting started

Each test stack consists of foundational infrastructure (an EKS cluster provisioned via Terraform), the backend application (deployed as Kubernetes pod or operator) and test client (load generation pod).

### Provision foundational infrastructure

* This step will create the necessary Amazon Virtual Private Cloud ([VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)), Subnets, Route Tables, Amazon Elastic Container Service for Kubernetes ([EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)), Amazon Elastic Container Registry ([ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)), [Argo Workflows](https://github.com/argoproj/argo-workflows), and [Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html) on Amazon EKS resources.
* Navigate to the `terraform-infra/` directory and run the following commands:

```
terraform init
terraform plan
terraform apply -auto-approve
```

### Update `kubectl` config

* Run the following command to update your kubectl config to work with the new EKS cluster:

```
aws eks update-kubeconfig --name graviton-perf-lab
```

### Create test nodes via Karpenter

* The test cluster created in the previous step relies on Karpenter to manage test infrastructure (by using the node pool concept)
* Navigate to the k8s-resources/ directory and apply the nodepool.yaml file:

```
kubectl apply -f nodepool.yaml
```

### Build test containers

* The test makes use of a sample application developed as part of the Graviton2 Workshop to demonstrate how to run a controlled experiment. Read the workshop documentation to learn more about [use case](https://catalog.workshops.aws/graviton/en-US/performance/introduction) and [test objective](https://catalog.workshops.aws/graviton/en-US/performance/test-objective).
* Run the following commands to build the test backend (Java 8 and Java 11) and test application which runs a HTTP benchmarking tool ([wrk2](https://github.com/giltene/wrk2)):

```
kubectl apply -f build-sut-java8.yaml
kubectl apply -f build-sut-java11.yaml

kubectl -n perf-test get pods/sut-builder-java8
kubectl -n perf-test get pods/sut-builder-java11


NAME READY STATUS RESTARTS AGE
sut-builder 0/1 Completed 0 103s
```

### Confirm build success

* Confirm containers for the test backend and test client were published successfully to ECR:

```
aws ecr list-images --repository-name=graviton-perf-lab/web-bookshop

imageIds:
- imageDigest: sha256:742b565bc523feb9c464fa5f421a587e21dabd6ac5a9ee1b3319899a81e97b4b
imageTag: 4.1.2-corretto-8
- imageDigest: sha256:a1067c69943a9b47812f47ce1b92a5d70d4cd28a696d3282b3dc4f3627113eed
imageTag: 4.1.2-corretto-11
```

## Run performance test

We provide a sample application and backend for the purpose of illustration. They are based on a containerized version of the original benchmark introduced by the [Graviton2 Workshop](https://catalog.workshops.aws/graviton/en-US/performance). Read the [use case description](https://catalog.workshops.aws/graviton/en-US/performance/introduction) and [test objective](https://catalog.workshops.aws/graviton/en-US/performance/test-objective) in the workshop material to understand what the test does.

The following table explains the baseline (SUT1) and alternative backend (SUT2). Running the test helps you determine which of the two options is more viable when compared against the test objective.

|Component	|SUT1	|SUT2	|
|---	|---	|---	|
|Backend	|Java 8 (Vertx 4.1)	|Java 11 (Vertx 4.1)	|
|Infrastructure	|Graviton2 (M6g)	|Graviton2 (M6g)	|

### Run test application (Java 8)

* Run the following command to start the Java 8 test:

```
kubectl apply -f argo-sut-test-1.yaml
```

### Run test application (Java 11)

* Run the following command to start the Java 11 test:

```
kubectl apply -f argo-sut-test-2.yaml
```

### Delete workflows

* Delete all the Argo Workflows using the following command:

```
kubectl -n perf-test delete workflows --all
```

## Inspect test results

Our test stack writes results to [AWS CloudWatch](https://aws.amazon.com/cloudwatch/) such that you always have a complete record of test execution and performance results. Note that there are different storage endpoints depending on the kind of information you want to observe. Application logs such as test statistics, error logs, and other text-based information goes into [Cloudwatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html). Application and infrastructure metrics such as CPU utilization, memory pressure, and other time series data is shipped to [Cloudwatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html) for the purpose of illustration.

### Inspect performance logs

* The test application emits logs and ships them to **CloudWatch Logs Insights**
* Navigate to the CloudWatch console: `https://<AWS_REGION>.console.aws.amazon.com/cloudwatch`
* Click on **Logs** in the left-hand side menu
* In the Logs menu, click **Logs Insights**
* In the dialog window, set **Selection criteria** to `/aws/containerinsights/graviton-perf-lab/application`
* Paste the following query into the query window

```
fields @timestamp, kubernetes.pod_name, log
| filter @entity.KeyAttributes.Name like "sut-java-11"
| filter stream like "stdout"
| sort @timestamp desc
| limit 10000
```

* Click **Run query** to inspect the output
* The query will display the standard output of the [wrk2](https://github.com/giltene/wrk2) HTTP benchmark run

## Optional: troubleshoot & optimize application

* The test application emits metrics and ships them to **CloudWatch Container Insights**
* Navigate to the CloudWatch console: https://<AWS_REGION>.console.aws.amazon.com/cloudwatch
* Click on **Insights** in the left-hand side menu
* In the Insights menu, click **Container Insights**
* In the top-right corner, click **View performance dashboards**
* Use the dashboard to inspect various aspects and performance metrics of your test cluster
