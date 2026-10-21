# RBAC matrix - flagship v2

Fictional Contoso personas. Scope: resource group rg-flagship-lab-uaen.

| Persona | Group | Role | Scope | Why this role | Must not be able to |
|---|---|---|---|---|---|
| Cloud engineer (Priya Nair) | grp-flagship-cloud-engineers | Contributor | rg-flagship-lab-uaen | Builds and changes lab resources | Give access to anyone; touch anything outside this resource group |
| SOC analyst (Alex Morgan) | grp-flagship-soc-analysts | Reader | rg-flagship-lab-uaen | Only needs to view resources and settings during an investigation | Change resources, change permissions, or assign roles |
| External auditor (Sam Patel) | grp-flagship-auditors | Reader + Storage Blob Data Reader (storage account only, added in Lab 3) | rg-flagship-lab-uaen / storage account | Must view settings and read evidence files, nothing else | Change, upload or delete anything |

## Design decisions

- Roles are assigned to groups, never directly to users. Moving someone between teams is one group change.
- Owner stays only with the subscription owner.
- Reader is a control-plane role. It shows a storage account but does not open the files in it. Reading files needs a separate data-plane role (Storage Blob Data Reader).
- Contributor can list storage access keys, which would give full access to the data. Shared-key access is disabled on the storage account (Lab 3), so data access only works through Entra ID roles.
- Planned (v3): SOC analysts get a role on the Sentinel workspace to investigate logs.
