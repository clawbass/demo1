resource "aws_secretsmanager_secret" "basic_user" { name = "demo1/basic_user" }
resource "aws_secretsmanager_secret_version" "basic_user" { secret_id = aws_secretsmanager_secret.basic_user.id secret_string = "admin" }

resource "aws_secretsmanager_secret" "basic_pass" { name = "demo1/basic_pass" }
resource "aws_secretsmanager_secret_version" "basic_pass" { secret_id = aws_secretsmanager_secret.basic_pass.id secret_string = "admin" }
