output "create_web_instances" {
  description = "public ip for the web instances"
  value       = [for o in module.create_web_instances : o.public_ip]
}


output "create_db_instance" {
  description = "public ip for the db instances"
  value       = [for o in module.create_db_instances : o.public_ip]
}

output "db_connection_instance" {
  description = "private ip for the db instances"
  value       = [for o in module.create_db_instances : o.private_ip]
}

output "elb_instance" {
  description = "public ip for the db instances"
  value       = module.elb.elb_dns_name
}

