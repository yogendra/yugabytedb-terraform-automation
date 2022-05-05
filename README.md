# YugabyteDB - Terraform Automation

This is project is a collection of automation scripts used for provisioning environments for demo/PoCs.

There are cloud / infra specific modules in the `modules/` directory. These are used for provisioning specific parts of infra

`envs/` folder has scripts for each environment that you want to maintain. An environment uses modules from the `modules/` folder.

## Automation Matrix

| Status | Name   | Pl. Infra | Cloud Infra       | Cloud  | Region | Zone  | Remarks |
| ------ | ------ | --------- | ----------------- | ------ | ------ | ----- | ------- |
| New    | lab-01 | GKE       | GKE, GCE          | Single | Single | Multi |         |
| New    | lab-02 | GKE       | GKE,GCE, EKS, EC2 | Multi  | Single | Multi |         |
| New    | lab-03 | GKE       | GKE,GCE, EKS, EC2 | Multi  | Single | Multi |         |

**Note:** Multi cloud setup require site-to-site VPN.

## Setup YugabyteDB Anywhere Terraform Provider

This is a private provider that is not published yet. Its available to YugabyteDB org members. It used the YugabyteDB Anywhere (formerly, Yugaware) API under the hood to work with a portal.

1. Become member of yugabyte team on github. Ask on the internal slack channel or community slack for this

1. Create local provider location

   ```bash
   mkdir -p ~/code/build/terraform-plugins
   ```

1. Clone the repo

   ```bash
   git clone https://github.com/yugabyte/terraform-provider-yugabytedb-anywhere.git ~/code/src/terraform-provider-yugabytedb-anywhere
   ```

1. Build provider

   ```bash
   cd ~/code/src/terraform-provider-yugabytedb-anywhere
   go build -o ~/code/build/terraform-plugins/terraform.yugabyte.com/platform/yugabyte-platform/0.1.0/darwin_arm64
   ```

1. Configure `.terraformrc`. This file may not even exist, so you can created a new one with following content. Replace `/home/ubuntu/code/build/terraform-plugin` with actual path of `~/code/build/terraform-plugin`

   ```hcl
   provider_installation {
     filesystem_mirror {
       path    = "/home/ubuntu/code/build/terraform-plugin"
       include = ["terraform.yugabyte.com/*/*"]
     }
     direct {
       exclude = ["terraform.yugabyte.com/*/*"]
     }
   }
   ```

1. Start using the module. You can create yugabyte resources like `yb_installation`, `yb_customer_resource`, etc.
