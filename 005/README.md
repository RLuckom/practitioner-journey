 terraform plan -var='domain_name=privilege-physics.com'
 terraform apply -var='domain_name=privilege-physics.com'
 terraform destroy -var='domain_name=privilege-physics.com' -var='force_destroy=true'

git clone https://github.com/RLuckom/practitioner-journey.git

cd practitioner-journey/005/

sudo ./setup.sh

Wait for prompt, then enter bucket name

cd terraform/

terraform init

terraform apply -var='maintainer_email=YOUR_EMAIL_ADDRESS'-var='domain_name=YOUR_DOMAIN' -var='twitter_handle=RLuckom' -var='linkedin_handle=raphaelluckom' -var='instagram_handle=RLuckom' -var='github_handle=RLuckom' -var='site_title=Test_Website'
terraform destroy -var='maintainer_email=YOUR_EMAIL_ADDRESS'-var='domain_name=YOUR_DOMAIN'

