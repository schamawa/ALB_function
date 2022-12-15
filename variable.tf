variable "image_id" {
  type = string
  default = "ami-06489866022e12a14"
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}

variable "vpc_cidr" {
  type = string
  default = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type = list(string)
  default = ["10.10.1.0/24", "10.10.3.0/24"]
}

variable "azs" {
  type = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

