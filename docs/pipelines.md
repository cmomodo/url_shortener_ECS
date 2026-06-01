we have already decided how to go about two of our workflows. codebuild cant directly deploy Terraform.

we are going to use built in github actions to deploy Terraform.

then we will use codedeploy via blue/green deployment for the containers. API/ dashboard will be deployed together, and the worker will be deployed separately.
