# terraform

```sh
terraform init
terraform apply -target=data.aws_subnet_ids.default
terraform apply
```

Provision may fail if EFS is not available yet. SSH login to retry manually.
