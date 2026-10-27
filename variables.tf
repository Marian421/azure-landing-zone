variable "subscription_id" {
  description = "Azure subscription to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for everything in the project"
  type        = string
  default     = "austriaeast"
}
