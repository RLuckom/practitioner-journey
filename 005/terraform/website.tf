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

variable allow_delete_buckets {
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
  unique_suffix = "2ae"
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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "aws_sdk" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/aws_sdk?ref=b5bfe1ef605186"
}

module "donut_days" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/donut_days?ref=b5bfe1ef605186"
}


module "image_dependencies" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/image_dependencies?ref=b5bfe1ef605186"
}

module "markdown_tools" {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/layers/markdown_tools?ref=b5bfe1ef605186"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
  supported_system_definitions = {
    alpha = {
      subsystems = {
        alpha_admin = {
          serverless_site_configs = {
            alpha_admin = {
              route53_zone_name = "${var.domain_name}."
              domain_parts = {
                top_level_domain = split(".", var.domain_name)[length(split(".", var.domain_name)) -1]
                controlled_domain_part = "admin.${join(".", slice(split(".", var.domain_name), 0, length(split(".", var.domain_name)) - 1))}"
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
              route53_zone_name = "${var.domain_name}."
              domain_parts = {
                top_level_domain = split(".", var.domain_name)[length(split(".", var.domain_name)) -1]
                controlled_domain_part = join(".", slice(split(".", var.domain_name), 0, length(split(".", var.domain_name)) - 1))
              }
            }
          }
        }
      }
    }
  }
}

module human_attention_archive {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/state/object_store/replicated_archive?ref=b5bfe1ef605186"
  unique_suffix = local.unique_suffix
  account_id = local.account_id
  really_allow_delete = var.allow_delete_buckets
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
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/serverless_site/plugins/blog?ref=b5bfe1ef605186"
  unique_suffix = local.unique_suffix
  name = "blog"
  region = local.region
  allow_delete_buckets = var.allow_delete_buckets
  account_id = local.account_id
  admin_site_resources = module.admin_interface.site_resources
  coordinator_data = module.visibility_system.serverless_site_configs["alpha_blog"]
  plugin_config = module.admin_interface.plugin_config["alpha_blog"]
  maintainer = local.maintainer
  nav_links = local.nav_links
  site_title = var.site_title
  logging_config = module.visibility_system.lambda_log_configs["alpha"]["human"].config
  image_layer = module.image_dependencies.layer_config
  donut_days_layer = module.donut_days.layer_config
  markdown_tools_layer = module.markdown_tools.layer_config
}

module admin_interface {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/serverless_site/derestreet?ref=b5bfe1ef605186"
  unique_suffix = local.unique_suffix
  account_id = local.account_id
  region = local.region
  system_id = module.visibility_system.serverless_site_configs["alpha_admin"].system_id
  allow_delete_buckets = var.allow_delete_buckets
  coordinator_data = module.visibility_system.serverless_site_configs["alpha_admin"]
  user_email = var.maintainer_email
  aws_sdk_layer = module.aws_sdk.layer_config
  plugin_static_configs = {
    alpha_blog = module.admin_site_blog_plugin.static_config
    visibility = module.admin_site_visibility_plugin.static_config
  }
  plugin_configs = {
    alpha_blog = {
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
      additional_connect_sources = module.admin_site_visibility_plugin.additional_connect_sources_required
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
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/visibility/aurochs?ref=b5bfe1ef605186"
  unique_suffix = local.unique_suffix
  allow_bucket_delete = var.allow_delete_buckets
  account_id = local.account_id
  region = local.region
  bucket_prefix = local.bucket_prefix
  donut_days_layer = module.donut_days.layer_config
  supported_system_definitions = local.supported_system_definitions
  cost_report_summary_reader_arns = [
    module.admin_interface.plugin_authenticated_roles["visibility"].arn
  ]
  visibility_bucket_cors_rules = [{
    allowed_headers = ["authorization", "content-md5", "content-type", "cache-control", "x-amz-content-sha256", "x-amz-date", "x-amz-security-token", "x-amz-user-agent"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://${module.admin_interface.website_config.domain}"]
    expose_headers = ["ETag"]
    max_age_seconds = 3000
  }]
  supported_system_clients = {
    alpha = {
      function_metric_table_read_role_names = []
      subsystems = {
        alpha_admin = {
          site_metric_table_read_role_name_map = {}
          scoped_logging_functions = concat(module.admin_site_blog_plugin.lambda_logging_arns)
          glue_permission_name_map = {
            add_partition_permission_names = []
            add_partition_permission_arns = []
            query_permission_names = [module.admin_interface.plugin_authenticated_roles["visibility"].name]
            query_permission_arns = [module.admin_interface.plugin_authenticated_roles["visibility"].arn]
          }
        }
        alpha_blog = {
          site_metric_table_read_role_name_map = {
            alpha_blog = [module.admin_interface.plugin_authenticated_roles["alpha_blog"].name]
          }
          scoped_logging_functions = concat(module.admin_site_blog_plugin.lambda_logging_arns)
          glue_permission_name_map = {
            add_partition_permission_names = []
            add_partition_permission_arns = []
            query_permission_names = []
            query_permission_arns = []
          }
        }
        human = {
          site_metric_table_read_role_name_map = {}
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
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/serverless_site/plugins/visibility?ref=b5bfe1ef605186"
  unique_suffix = local.unique_suffix
  name = "visibility"
  account_id = local.account_id
  region = local.region
  admin_site_resources = module.admin_interface.site_resources
  data_warehouse_configs = module.visibility_system.data_warehouse_configs
  serverless_site_configs = module.visibility_system.serverless_site_configs
  cost_report_summary_location = module.visibility_system.cost_report_summary_location
  plugin_config = module.admin_interface.plugin_config["visibility"]
}
