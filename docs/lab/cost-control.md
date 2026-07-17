# Cost control

The default path excludes AKS and Key Vault. AKS uses the Free management tier,
but VMs, managed disks, load balancing, public IPs, logs, managed Prometheus,
network traffic, and egress remain billable. Microsoft describes the AKS Free
tier as no-SLA experimentation where users still pay for the underlying
resources.

## Planning envelope

The following is a deliberately broad safety envelope, not a quote:

| Scenario | Operating assumption | Planning envelope |
| --- | --- | ---- |
| Foundation-only, idle | State storage, VNet/NSGs, policy, mostly empty Log Analytics workspace | approximately EUR 0-5/month |
| One short AKS exercise | One `Standard_D2s_v5` node for up to four hours, limited logs, same-day destroy | approximately EUR 1-5/session |
| AKS left running continuously | One node, disk/load-balancer/networking, Container Insights and metrics | approximately EUR 100-250+/month |

Actual prices vary by region, offer, currency, usage, and date. Recalculate in
the Azure Pricing Calculator immediately before deployment. Azure Monitor bills
log ingestion and managed Prometheus metrics separately; a 1 GB/day quota is a
ceiling, not a free allowance.

## Controls

Before deployment:

1. create an Azure Budget with low thresholds and email alerts;
2. review the Terraform plan and current Azure calculator estimate;
3. keep `enable_aks=false` for the first lifecycle test;
4. keep optional services disabled;
5. use no production data;
6. schedule same-day teardown.

After destroy, verify resource groups, disks, public IPs, load balancers,
private endpoints, and monitoring workspaces through Azure inventory rather
than trusting state alone.

## Monitoring toggle

`enable_aks_monitoring=false` disables both Container Insights and the managed
Prometheus add-on in the AKS resource. Control-plane diagnostic settings remain
configured when AKS exists; the Log Analytics daily quota is the final cost
circuit breaker for the lab.
