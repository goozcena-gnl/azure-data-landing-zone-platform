mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "11111111-1111-1111-1111-111111111111"
}

run "foundation_defaults_are_valid" {
  command = plan
}

run "jupyter_requires_aks" {
  command = plan

  variables {
    enable_aks     = false
    enable_jupyter = true
  }

  expect_failures = [var.enable_jupyter]
}

run "aks_requires_an_admin_group" {
  command = plan

  variables {
    enable_aks                  = true
    aks_authorized_ip_ranges    = ["203.0.113.10/32"]
    aks_admin_group_object_ids  = []
    aks_private_cluster_enabled = false
    enable_aks_monitoring       = false
    enable_aks_azure_policy     = false
  }

  expect_failures = [var.aks_admin_group_object_ids]
}

run "admin_group_ids_must_be_uuids" {
  command = plan

  variables {
    aks_admin_group_object_ids = [""]
  }

  expect_failures = [var.aks_admin_group_object_ids]
}

run "node_count_stays_within_lab_limit" {
  command = plan

  variables {
    aks_node_count = 4
  }

  expect_failures = [var.aks_node_count]
}

run "node_count_must_be_whole" {
  command = plan

  variables {
    aks_node_count = 1.5
  }

  expect_failures = [var.aks_node_count]
}

run "vm_size_cannot_be_empty" {
  command = plan

  variables {
    aks_node_vm_size = ""
  }

  expect_failures = [var.aks_node_vm_size]
}

run "location_cannot_be_empty" {
  command = plan

  variables {
    location = ""
  }

  expect_failures = [var.location]
}
