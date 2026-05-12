variable "local_public_key" {
    description    = "The public key of the local machine"
    type            = string
    sensitive       = true
}

variable "ec2_private_key" {
    description      = "The private key for the EC2 insstance"
    type            = string
    sensitive       = true
}
