resource "azurerm_cdn_frontdoor_endpoint" "this" {
  for_each = var.sites

  name                     = "fde-${each.key}"
  cdn_frontdoor_profile_id = var.profile_id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  for_each = var.sites

  name                     = "og-${each.key}"
  cdn_frontdoor_profile_id = var.profile_id

  load_balancing {}

  health_probe {
    protocol            = each.value.origin_protocol
    interval_in_seconds = 120
    path                = "/"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  for_each = var.sites

  name                           = "origin-${each.key}"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.this[each.key].id
  host_name                      = each.value.host_name
  origin_host_header             = each.value.host_name
  certificate_name_check_enabled = true
  http_port                      = 80
  https_port                     = 443
}

resource "azurerm_cdn_frontdoor_route" "this" {
  for_each = var.sites

  name                          = "route-${each.key}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this[each.key].id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this[each.key].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.this[each.key].id]

  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  https_redirect_enabled = true
  forwarding_protocol    = each.value.origin_protocol == "Https" ? "HttpsOnly" : "HttpOnly"
  link_to_default_domain = true
}
