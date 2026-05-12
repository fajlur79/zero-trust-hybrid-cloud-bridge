resource "aws_ssm_parameter" "ec2_wg_private" {
    name    = "ec2_private_key"
    type    = "SecureString"
    value   = var.ec2_private_key
}

resource "aws_iam_role" "wg_ec2_role" {
    name = "wireguard_ec2_role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_policy" "ssm_read_policy" {
    name        = "wireguard_ssm_read_policy"
    description = "Allow EC2 to read its WireGuard private key"

    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = aws_ssm_parameter.ec2_wg_private.arn
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ssm_attach" {
    role        = aws_iam_role.wg_ec2_role.name
    policy_arn  = aws_iam_policy.ssm_read_policy.arn
}

resource "aws_iam_instance_profile" "wg_profile" {
    name    = "wireguard_intance_profile"
    role    = aws_iam_role.wg_ec2_role.name
}
