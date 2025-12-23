
#!/bin/bash

cd 02-functions

terraform init
terraform destroy -auto-approve

cd ..

cd 01-pubsub 

terraform init
terraform destroy -auto-approve

cd ..

