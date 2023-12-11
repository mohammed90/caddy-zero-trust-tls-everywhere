variable "do_token" {
  sensitive = true
}

variable "do_region" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "base_subdomain" {
  type = string
  validation {
    condition     = length(var.base_subdomain) == 0 || endswith(var.base_subdomain, ".")
    error_message = "accepted value is either empty string or ends with a '.' (dot)"
  }
  default = ""
}

variable "ca_name" {
  type = string
}
