variable domain_name {
  type = string
}

variable maintainer_email {
  type = string
}

variable bucket_prefix {
  type = string
  default = ""
}

resource "random_id" "bucket_prefix" {
  byte_length = 3
}

locals {
  bucket_prefix = var.bucket_prefix == "" ? random_id.bucket_prefix.hex : var.bucket_prefix
}

variable force_destroy {
  type = bool
  default = true
}

variable maintainer_name {
  type = string
  default = "Maintainer Name"
}

variable site_title {
  type = string
  default = "Test_Website"
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
  site_title = replace(var.site_title, "_", " ")
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

variable supported_system_definitions {
  type = map(object({
    subsystems = map(object({
      serverless_site_configs = map(object({
        route53_zone_name = string
        domain_parts = object({
          top_level_domain = string
          controlled_domain_part = string
        })
      }))
    }))
  }))
  default = {
    alpha = {
      subsystems = {
        alpha_admin = {
          serverless_site_configs = {
            alpha_admin = {
              route53_zone_name = "raphaelluckom.com."
              domain_parts = {
                top_level_domain = "com"
                controlled_domain_part = "admin.raphaelluckom"
              }
            }
          }
        }
        human = {
          serverless_site_configs = {}
        }
        alpha_blog = {
          serverless_site_configs = {
            alpha_blog = {
              route53_zone_name = "raphaelluckom.com."
              domain_parts = {
                top_level_domain = "com"
                controlled_domain_part = "test.raphaelluckom"
              }
            }
          }
        }
      }
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "aws_sdk" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/aws_sdk?ref=89757f496551e05034807"
}

module "donut_days" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/donut_days?ref=89757f496551e05034807"
}


module "image_dependencies" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/image_dependencies?ref=89757f496551e05034807"
}

module "markdown_tools" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/markdown_tools?ref=89757f496551e05034807"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

module human_attention_archive {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/state/object_store/replicated_archive?ref=89757f496551e05034807"
  account_id = local.account_id
  region = local.region
  providers = {
    aws.replica1 = aws.frankfurt
    aws.replica2 = aws.sydney
    aws.replica3 = aws.canada
  }
  bucket_prefix = local.bucket_prefix
  security_scope = "alpha"
  replication_function_logging_config = module.visibility_system.lambda_log_configs["alpha"]["human"].config
  donut_days_layer_config = module.donut_days.layer_config
  replication_sources = [{
    bucket = module.admin_interface.website_config.bucket_name
    prefix = "uploads/"
    suffix = ""
    filter_tags = {}
    completion_tags = [{
      Key = "Archived"
      Value = "true"
    }]
    storage_class = "GLACIER"
  }]
}

module admin_site_blog_plugin {
  source = "github.com/RLuckom/raphaelluckom.com//terraform/modules/plugins/blog"
  name = "blog"
  region = local.region
  account_id = local.account_id
  admin_site_resources = module.admin_interface.site_resources
  coordinator_data = module.visibility_system.serverless_site_configs["alpha_blog"]
  plugin_config = module.admin_interface.plugin_config["blog"]
  maintainer = local.maintainer
  nav_links = local.nav_links
  site_title = var.site_title
  logging_config = module.visibility_system.lambda_log_configs["alpha"]["human"].config
  image_layer = module.image_dependencies.layer_config
  donut_days_layer = module.donut_days.layer_config
  markdown_tools_layer = module.markdown_tools.layer_config
}

module admin_interface {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/serverless_site/derestreet?ref=89757f496551e05034807"
  account_id = local.account_id
  region = local.region
  system_id = module.visibility_system.serverless_site_configs["alpha_admin"].system_id
  coordinator_data = module.visibility_system.serverless_site_configs["alpha_admin"]
  user_email = var.maintainer_email
  aws_sdk_layer = module.aws_sdk.layer_config
  plugin_static_configs = {
    blog = module.admin_site_blog_plugin.static_config
    visibility = module.admin_site_visibility_plugin.static_config
  }
  plugin_configs = {
    blog = {
      additional_connect_sources = module.admin_site_blog_plugin.additional_connect_sources_required
      additional_style_sources = []
      policy_statements = []
      plugin_relative_lambda_origins = module.admin_site_blog_plugin.plugin_relative_lambda_origins
      plugin_relative_bucket_upload_permissions_needed = module.admin_site_blog_plugin.plugin_relative_bucket_upload_permissions_needed
      plugin_relative_bucket_list_permissions_needed = module.admin_site_blog_plugin.plugin_relative_bucket_list_permissions_needed
      plugin_relative_bucket_host_permissions_needed = module.admin_site_blog_plugin.plugin_relative_bucket_host_permissions_needed 
      upload_path_lambda_notifications = module.admin_site_blog_plugin.plugin_relative_lambda_notifications
      storage_path_lambda_notifications = []
      file_configs = module.admin_site_blog_plugin.files
    }
    visibility = {
      additional_connect_sources = []
      additional_style_sources = []
      policy_statements = []
      plugin_relative_lambda_origins = []
      storage_path_lambda_notifications = []
      upload_path_lambda_notifications = []
      plugin_relative_bucket_upload_permissions_needed = []
      plugin_relative_bucket_list_permissions_needed = []
      plugin_relative_bucket_host_permissions_needed = []
      lambda_notifications = []
      file_configs = module.admin_site_visibility_plugin.files
    }
  }
  archive_system = {
    bucket_permissions_needed = module.human_attention_archive.replication_function_permissions_needed[module.admin_interface.website_config.bucket_name]
    lambda_notifications = module.human_attention_archive.bucket_notifications[module.admin_interface.website_config.bucket_name]
  }
}

module visibility_system {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/visibility/aurochs?ref=89757f496551e05034807"
  account_id = local.account_id
  region = local.region
  cloudfront_delivery_bucket = "${local.bucket_prefix}-cloudfront-delivery"
  visibility_data_bucket = "${local.bucket_prefix}-visibility-data"
  donut_days_layer = module.donut_days.layer_config
  supported_system_definitions = var.supported_system_definitions
  supported_system_clients = {
    alpha = {
      subsystems = {
        alpha_admin = {
          scoped_logging_functions = concat(module.admin_site_blog_plugin.lambda_logging_arns)
          glue_permission_name_map = {
            add_partition_permission_names = []
            add_partition_permission_arns = []
            query_permission_names = [module.admin_interface.plugin_authenticated_roles["visibility"].name]
            query_permission_arns = [module.admin_interface.plugin_authenticated_roles["visibility"].arn]
          }
        }
        alpha_blog = {
          scoped_logging_functions = concat(module.admin_site_blog_plugin.lambda_logging_arns)
          glue_permission_name_map = {
            add_partition_permission_names = []
            add_partition_permission_arns = []
            query_permission_names = []
            query_permission_arns = []
          }
        }
        human = {
          scoped_logging_functions = concat(module.human_attention_archive.lambda_logging_roles)
          glue_permission_name_map = {
            add_partition_permission_names = []
            add_partition_permission_arns = []
            query_permission_names = []
            query_permission_arns = []
          }
        }
      }
    }
  }
}

module admin_site_visibility_plugin {
  source = "github.com/RLuckom/raphaelluckom.com//terraform/modules/plugins/visibility"
  name = "visibility"
  account_id = local.account_id
  region = local.region
  admin_site_resources = module.admin_interface.site_resources
  plugin_config = module.admin_interface.plugin_config["visibility"]
}
