 terraform plan -var='domain_name=privilege-physics.com'
 terraform apply -var='domain_name=privilege-physics.com'
 terraform destroy -var='domain_name=privilege-physics.com' -var='force_destroy=true'

git clone https://github.com/RLuckom/practitioner-journey.git

cd practitioner-journey/004/

sudo ./setup.sh

Wait for prompt, then enter bucket name

cd terraform/

terraform init
