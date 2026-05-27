data "aws_route53_zone" "wordpress" {
  count        = var.create_route53_record ? 1 : 0
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_iam_role" "ec2_s3fs_role" {
  name = "${var.project_name}-ec2-s3fs-role"

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

  tags = {
    Name        = "${var.project_name}-ec2-s3fs-role"
    Environment = var.environment
  }
}

resource "aws_iam_instance_profile" "ec2_s3fs_profile" {
  name = "${var.project_name}-ec2-s3fs-profile"
  role = aws_iam_role.ec2_s3fs_role.name
}

resource "aws_iam_role_policy_attachment" "s3fs_attach" {
  role       = aws_iam_role.ec2_s3fs_role.name
  policy_arn = var.s3fs_policy_arn
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_s3fs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = base64encode(templatefile("${path.module}/../../scripts/userdata.sh.tpl", {
    db_name           = var.db_name
    db_username       = var.db_username
    db_password       = var.db_password
    db_endpoint       = var.db_endpoint
    s3_bucket         = var.s3_bucket_name
    aws_region        = var.region
    domain_name       = var.domain_name
    wp_site_title     = var.wp_site_title
    wp_admin_user     = var.wp_admin_user
    wp_admin_password = var.wp_admin_password
    wp_admin_email    = var.wp_admin_email
  }))

  vpc_security_group_ids = [var.asg_security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_s3fs_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-wordpress"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-launch-template"
    Environment = var.environment
  }
}

resource "aws_lb" "wordpress" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "wordpress" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health.html"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_route53_record" "wordpress" {
  count           = var.create_route53_record ? 1 : 0
  zone_id         = data.aws_route53_zone.wordpress[0].zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_lb.wordpress.dns_name
    zone_id                = aws_lb.wordpress.zone_id
    evaluate_target_health = true
  }
}

resource "aws_autoscaling_group" "wordpress" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.wordpress.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 900
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity

  depends_on = [
    aws_iam_role_policy_attachment.s3fs_attach,
    aws_iam_role_policy_attachment.ssm_attach,
    aws_lb_listener.https
  ]

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      instance_warmup        = 900
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-wordpress"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
}

resource "aws_cloudwatch_metric_alarm" "scale_out" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when CPU exceeds 70%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale_in" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in when CPU stays low"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}
