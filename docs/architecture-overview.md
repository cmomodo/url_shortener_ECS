# Architecture Overview

```mermaid
flowchart TB
  user[User]
  dns[Route 53<br/>ceedev.co.uk / www]
  cf[CloudFront]
  waf[WAF]
  alb[Application Load Balancer]

  subgraph app[Private ECS Fargate Cluster]
    api[API service<br/>shorten, redirect, publish events]
    dashboard[Dashboard service<br/>analytics API]
    worker[Worker service<br/>consume click events]
  end

  subgraph data[Data Layer]
    redis[ElastiCache Redis]
    sqs[SQS queue]
    rds[RDS PostgreSQL]
  end

  subgraph support[Platform Services]
    ecr[ECR images]
    ssm[SSM parameters]
    kms[KMS]
    logs[CloudWatch Logs]
    cd[CodeDeploy blue/green]
    gha[GitHub Actions]
  end

  user --> dns --> cf --> waf --> alb
  alb -->|/summary, /top, /recent, /url/*| dashboard
  alb -->|default| api

  api --> redis
  api --> sqs
  api --> rds
  dashboard --> rds
  worker --> sqs
  worker --> rds

  ecr -. pulls images .-> api
  ecr -. pulls images .-> dashboard
  ecr -. pulls images .-> worker

  ssm -. secrets .-> api
  ssm -. secrets .-> dashboard
  ssm -. secrets .-> worker

  kms -. encrypts .-> redis
  kms -. encrypts .-> sqs
  kms -. encrypts .-> rds

  api -. logs .-> logs
  dashboard -. logs .-> logs
  worker -. logs .-> logs

  gha -. deploys .-> cd
  cd -. updates .-> api
  cd -. updates .-> dashboard
```

## High-Level Flow

1. The user resolves `ceedev.co.uk` or `www.ceedev.co.uk` through Route 53.
1. Traffic passes through CloudFront and WAF before reaching the public ALB.
1. The ALB routes dashboard requests to the dashboard service and everything else to the API service.
1. The API writes URL data to PostgreSQL, caches reads in Redis, and publishes click events to SQS.
1. The worker consumes SQS messages and persists analytics back to PostgreSQL.
1. GitHub Actions pushes images to ECR and uses CodeDeploy for blue/green updates of the ECS services.
