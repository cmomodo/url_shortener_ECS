at the moment we are using terraform to deploy the infrastructure for the url shortener.

we are using the following files:

- terraform.tfvars
- variables.tf
- outputs.tf
- main.tf

we are using the following providers:

- aws
- terraform
- terraform-provider-aws

we are using the following modules:

- aws_vpc
- aws_subnet
- aws_security_group
- aws_instance
- aws_load_balancer
- aws_load_balancer_listener
- aws_load_balancer_target_group

```
cd infra
terraform apply

```

```
cd infra
terraform apply -target=aws_lb.main -replace=aws_lb.main
```

```
cd infra
terraform apply
```

This is because we set the delete protection to true in the ecs.tf file.
