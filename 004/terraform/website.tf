variable domain_name {
  type = string
}

variable force_destroy {
  type = bool
  default = false
}

variable maintainer_name {
  type = string
  default = "Maintainer Name"
}

variable maintainer_email {
  type = string
  default = "name@example.com"
}

variable site_title {
  type = string
  default = "Test Website"
}

variable twitter_handle {
  type = string
  default = ""
}

variable linkedin_handle {
  type = string
  default = ""
}

variable instagram_handle {
  type = string
  default = ""
}

variable github_handle {
  type = string
  default = ""
}

variable security_scope {
  type = string
  default = "pract"
}

variable subsystem_name {
  type = string
  default = "site"
}

locals {
  maintainer = {
    name = var.maintainer_name
    email = var.maintainer_email
  }
  site_title = var.site_title
  potential_nav_links = [
    {
      name = "Github"
      prefix = "https://github.com/"
      handle = var.github_handle
    },
    {
      name = "LinkedIn"
      prefix = "https://www.linkedin.com/in/"
      handle = var.linkedin_handle
    },
    {
      name = "Twitter"
      prefix = "https://twitter.com/"
      handle = var.twitter_handle
    },
    {
      name = "Instagram"
      prefix = "https://www.instagram.com/"
      handle = var.instagram_handle
    }
  ]
  nav_links = [
    for link in local.potential_nav_links : {
      name = link.name
      target = "${link.prefix}${link.handle}"
    } if link.handle != ""
  ]
  domain_parts = {
    top_level_domain = regex("(?P<controlled_domain_part>[^.]*).(?P<top_level_domain>.*)", var.domain_name).top_level_domain
    controlled_domain_part = regex("(?P<controlled_domain_part>[^.]*).(?P<top_level_domain>.*)", var.domain_name).controlled_domain_part
  }
  route53_zone_name = "${var.domain_name}."
  system_id = {
    security_scope = var.security_scope
    subsystem_name = var.subsystem_name
  }
  routing = {
    domain_parts = local.domain_parts
    route53_zone_name = local.route53_zone_name
  }
}

module website {
  source = "github.com/RLuckom/terraform_modules//aws/serverless_site/tetrapod"
  maintainer = local.maintainer
  force_destroy = var.force_destroy
  nav_links = local.nav_links
  site_title = local.site_title
  system_id = local.system_id
  routing = local.routing
}
