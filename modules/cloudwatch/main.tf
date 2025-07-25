resource "aws_cloudwatch_dashboard" "employee_app_dashboard" {
  dashboard_name = "EmployeeApp-Overview"
  dashboard_body = jsonencode({
    "widgets" = [
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_id],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 300
          "stat"    = "Average"
          "region"  = var.aws_region
          "title"   = "Key Infrastructure Metrics"
        }
      },
      {
        "type"   = "metric"
        "x"      = 12
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["EmployeeApp/Flask", "ErrorCount", "Application", "EmployeeApp"]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 300
          "stat"    = "Sum"
          "region"  = var.aws_region
          "title"   = "Application Error Count"
        }
      },
      {
        "type"   = "log"
        "x"      = 0
        "y"      = 6
        "width"  = 24
        "height" = 6
        "properties" = {
          "query"  = "SOURCE '${var.log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          "region" = var.aws_region
          "title"  = "Recent Application Logs"
          "view"   = "table"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "employee_app_application_health_dashboard" {
  dashboard_name = "EmployeeApp-ApplicationHealth"
  dashboard_body = jsonencode({
    "widgets" = [
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["EmployeeApp/Flask", "RequestDuration", "Endpoint", "all", { "stat": "Average", "label": "Avg Request Duration" }],
            ["EmployeeApp/Flask", "RequestDuration", "Endpoint", "all", { "stat": "p90", "label": "P90 Request Duration" }],
            ["EmployeeApp/Flask", "ErrorCount", "Application", "EmployeeApp", { "stat": "Sum", "label": "Total Errors" }]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 60
          "stat"    = "Average"
          "region"  = var.aws_region
          "title"   = "Application Performance"
        }
      },
      {
        "type"   = "metric"
        "x"      = 12
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["AWS/ECS", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 300
          "stat"    = "Average"
          "region"  = var.aws_region
          "title"   = "ECS Service Health"
        }
      },
      {
        "type"   = "log"
        "x"      = 0
        "y"      = 6
        "width"  = 24
        "height" = 6
        "properties" = {
          "query"  = "SOURCE '${var.log_group_name}' | filter @message like /error|exception/ | fields @timestamp, @message | sort @timestamp desc | limit 20"
          "region" = var.aws_region
          "title"  = "Recent Application Errors in Logs"
          "view"   = "table"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "employee_app_database_performance_dashboard" {
  dashboard_name = "EmployeeApp-DatabasePerformance"
  dashboard_body = jsonencode({
    "widgets" = [
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id, { "label": "CPU Utilization (Average)" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Database Connections (Average)" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Free Storage Space (Min)", "stat": "Minimum", "yAxis": { "showUnits": true } }]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 300
          "stat"    = "Average"
          "region"  = var.aws_region
          "title"   = "RDS Core Performance"
        }
      },
      {
        "type"   = "metric"
        "x"      = 12
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Read IOPS (Average)" }],
            ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Write IOPS (Average)" }],
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Read Latency (Average)" }],
            ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Write Latency (Average)" }]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 300
          "stat"    = "Average"
          "region"  = var.aws_region
          "title"   = "RDS I/O Performance"
        }
      },
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 6
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            ["AWS/RDS", "NetworkReceiveThroughput", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Network Receive (Average)" }],
            ["AWS/RDS", "NetworkTransmitThroughput", "DBInstanceIdentifier", var.rds_instance_id, { "label": "Network Transmit (Average)" }]
          ]
          "view"    = "timeSeries"
          "stacked" = false
          "period"  = 300
          "stat"    = "Average"
          "region"  = var.aws_region
          "title"   = "RDS Network Throughput"
        }
      }
    ]
  })
}