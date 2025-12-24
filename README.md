## Key Highlights

- Implemented Auto Scaling Groups (ASG) to minimize downtime by automatically replacing unhealthy instances.
- Configured CPU utilization thresholds to terminate overloaded instances and launch new ones seamlessly.
- Hosted a sample web application on EC2 instances managed by the ASG.
- Direct access via instance Public IP is restricted — the application is reachable only through the Load Balancer’s Public DNS.
- Ensures high availability, fault tolerance, and secure traffic routing to target groups.
