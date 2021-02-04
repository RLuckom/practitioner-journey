variable domain_name {
  type = string
}

variable force_destroy {
  type = bool
  default = true
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

resource "aws_s3_bucket_object" "object" {
  bucket = module.website.website_bucket_name
  key = "posts/"
  content = ""
  depends_on = [module.website]
}

resource "aws_s3_bucket_object" "object" {
  bucket = module.website.website_bucket_name
  key = "images/"
  content = ""
  depends_on = [module.website]
}

resource "aws_s3_bucket_object" "object" {
  bucket = module.website.website_bucket_name
  key = "images/state_diagram.svg"
  source = "images/state_diagram.svg"
  depends_on = [module.website]
}

resource "aws_s3_bucket_object" "object" {
  bucket = module.website.website_bucket_name
  key    = "posts/test_post.md"
  depends_on = [module.website]
  content = <<EOF
---
title: "Test Post"
author: "System"
date: 2021-02-03T12:00:00
meta:
  trail:
    - test
    - cloud
---

## Main Heading

### SubHeading

#### Sub-Sub Heading
This is a test post autogenerated by the system described [here](https://raphaelluckom.com/posts/practitioner_journey_004.html)
on first deployment. 

_This is italic text_

__This is bold text__

This text has a footnote[^1].

```
This is a code block
```

![Alt Text on an SVG image showing the state view of the system](/images/state_diagram.svg) 

This is a numbered list:

1. First item
2. Second item

This is a bullet list
* First item
* Second item

This is a regular paragraph

> This is a block quote


[^1]: This is the text of the footnote
      It spans multiple lines.
      
      > You can even include a pull quote
EOF
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
