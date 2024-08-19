module "basic_ec2_application" {
  source = "../.."
  # Load Balancer configuration
  create_load_balancer     = true
  load_balancer_name       = "my-application-load-balancer"
  vpc_id                   = "vpc-90d458fb"
  load_balancer_subnet_ids = ["subnet-7ab60211", "subnet-a1db39dc"]
  load_balancer_internal   = false
  load_balancer_type       = "application"

  # Listener and Target configuration
  listener_port = 80
  target_port   = 80
  protocol      = "HTTP"

  # Auto Scaling Group (ASG) configuration
  asg_name            = "my-auto-scaling-group"
  asg_min_size        = 2
  asg_max_size        = 5
  asg_desire_capacity = 3
  asg_subnet_ids      = ["subnet-7ab60211", "subnet-a1db39dc"]

  # Scaling policies for ASG
  scaling_policies = {
    "step-scaling-policy" = {
      name            = "step-scaling-policy"
      adjustment_type = "ChangeInCapacity"
      policy_type     = "StepScaling"
      step_adjustment = [
        {
          scaling_adjustment          = 1
          metric_interval_lower_bound = 0
          metric_interval_upper_bound = 10
        },
        {
          scaling_adjustment          = 2
          metric_interval_lower_bound = 10
        }
      ]

      metric_alarm = {
        alarm_name          = "test-alarm-cpu"
        comparison_operator = "GreaterThanThreshold"
        evaluation_periods  = 1
        metric_name         = "CPUUtilization"
      }
    }

    "target_tracking_policy" = {
      name                      = "target-tracking-policy"
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 300
      target_tracking_configuration = {
        target_value     = 75.0
        disable_scale_in = false

        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
      }
    }
  }

  # Launch template configuration
  create_launch_template      = true
  launch_template_name        = "my-launch-template"
  launch_template_description = "Launch template for ASG instances"
  ami                         = "ami-0862be96e41dcbf74"
  instance_type               = "t3.micro"
  user_data                   = <<EOF
#!/bin/bash
# Update the package index
apt-get update -y
 
# Install Nginx
apt-get install -y nginx
 
# Start Nginx service
systemctl start nginx
 
# Enable Nginx to start on boot
systemctl enable nginx
EOF

  # Route 53 and ACM configuration
  create_hosted_zone = true
  domain_name        = "tuannguyenduc.id.vn"
  domain_comment     = "Hosted zone for tuannguyenduc.id.vn"
  enable_https       = false
  
  # Tagging configuration
  tags = {
    "Environment" = "production"
    "Project"     = "my-project"
  }


}