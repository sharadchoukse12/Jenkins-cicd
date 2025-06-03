variable "ami_id" {
    type = string
    description = "The AMI ID to use for servers"
    default = "ami-0fc5d935ebf8bc3bc"
}

variable "instance_size" {
    type = string
    description = "The instance type to use for servers"
    default = "t2.medium"
}



