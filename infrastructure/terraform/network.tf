data "aws_vpc" "default" { default = true }
data "aws_subnets" "public" { filter { name="vpc-id" values=[data.aws_vpc.default.id] } }

resource "aws_security_group" "alb" {
  name   = "${var.project}-alb-sg"
  vpc_id = data.aws_vpc.default.id
  ingress { from_port=80  to_port=80  protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  ingress { from_port=443 to_port=443 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_security_group" "service" {
  name   = "${var.project}-svc-sg"
  vpc_id = data.aws_vpc.default.id
  ingress { from_port=80 to_port=80 protocol="tcp" security_groups=[aws_security_group.alb.id] }
  egress  { from_port=0  to_port=0  protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}
