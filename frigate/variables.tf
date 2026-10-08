variable "config" {
  type = object({
    mqtt_user        = string
    mqtt_password    = string
    camera_user      = string
    camera1_host     = string
    camera1_password = string
    camera2_host     = string
    camera2_password = string
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "private_domain" {
  type = string
}

variable "mqtt_host" {
  description = "Address of the MQTT broker, e.g. the mosquitto instance from the homeassistant module"
  type        = string
}

variable "storage_pool" {
  type = string
}

variable "storage_source" {
  type = string
}
