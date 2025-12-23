
#!/bin/bash

cd 03-webapp
terraform init
terraform destroy -auto-approve
cd ..


cd 02-functions
terraform init
terraform destroy -auto-approve
cd ..

cd 01-pubsub 
terraform init
terraform destroy -auto-approve
cd ..

