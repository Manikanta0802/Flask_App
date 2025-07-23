#!/bin/bash
sudo yum update -y
sudo yum install -y telnet net-tools # Basic tools for debugging
# Optional: Install Session Manager Agent if not already present on your AMI,
# but Amazon Linux 2 usually comes with it for managed instance core.
