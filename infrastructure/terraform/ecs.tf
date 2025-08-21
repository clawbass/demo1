resource "aws_ecs_cluster" "this" { name = "${var.project}-cluster" }

resource "aws_cloudwatch_log_group" "logs" { name = "/ecs/${var.project}" retention_in_days = 30 }

# shared ephemeral volume for .htpasswd between sidecar and proxy
locals {
  container_port = 80
}

data "aws_ecr_repository" "proxy"    { name = aws_ecr_repository.proxy.name }
data "aws_ecr_repository" "frontend" { name = aws_ecr_repository.frontend.name }
data "aws_ecr_repository" "backend"  { name = aws_ecr_repository.backend.name }

# task definition JSON
locals {
  container_definitions = jsonencode([
    {
      name      = "htpasswd-init"
      image     = "alpine:3.20"
      essential = false
      command   = ["sh","-c","apk add --no-cache apache2-utils && htpasswd -bc /auth/.htpasswd \"$BASIC_USER\" \"$BASIC_PASS\" && tail -f /dev/null"]
      environment = []
      secrets = [
        { name = "BASIC_USER", valueFrom = aws_secretsmanager_secret_version.basic_user.arn },
        { name = "BASIC_PASS", valueFrom = aws_secretsmanager_secret_version.basic_pass.arn }
      ]
      mountPoints = [{ sourceVolume = "auth-vol", containerPath = "/auth" }]
    },
    {
      name      = "proxy"
      image     = "${data.aws_ecr_repository.proxy.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 80 }]
      logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.logs.name, awslogs-region = var.region, awslogs-stream-prefix = "proxy" } }
      mountPoints = [{ sourceVolume = "auth-vol", containerPath = "/etc/nginx/auth" }]
      dependsOn  = [{ containerName = "htpasswd-init", condition = "START" }]
    },
    {
      name = "frontend"
      image = "${data.aws_ecr_repository.frontend.repository_url}:latest"
      essential = false
      portMappings = [{ containerPort = 80 }]
      logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.logs.name, awslogs-region = var.region, awslogs-stream-prefix = "frontend" } }
    },
    {
      name = "backend"
      image = "${data.aws_ecr_repository.backend.repository_url}:latest"
      essential = false
      portMappings = [{ containerPort = 8080 }]
      logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.logs.name, awslogs-region = var.region, awslogs-stream-prefix = "backend" } }
    }
  ])
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.project
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions    = local.container_definitions
  volume {
    name = "auth-vol"
  }
}

resource "aws_ecs_service" "this" {
  name            = "${var.project}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    assign_public_ip = true
    subnets         = data.aws_subnets.public.ids
    security_groups = [aws_security_group.service.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "proxy"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.https]
}
