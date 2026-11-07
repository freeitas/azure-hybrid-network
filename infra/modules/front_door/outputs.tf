output "endpoint_hostnames" {
  description = "Public hostname of each site."
  value       = { for name, endpoint in azurerm_cdn_frontdoor_endpoint.this : name => endpoint.host_name }
}
