variable "region" {
  default = "ap-south-1"
}

variable "ami" {
  type = map(string)
  default = {
    master = "ami-007020fd9c84e18c7"
    worker = "ami-007020fd9c84e18c7"
  }
}

variable "instance_type" {
  type = map(string)
  default = {
    master = "t2.medium"
    worker = "t2.micro"
  }
}

variable "worker_instance_count" {
  type    = number
  default = 2
}