# Incident report: excessive privilege granted to external auditors group

**Date:** 21 Oct 2026 · **Environment:** flagship lab (fictional Contoso data) · **Severity:** High (lab simulation)

## Summary
The Contributor role was granted to grp-flagship-auditors on rg-flagship-lab-uaen. External auditors should have read-only access. The change was detected with KQL, confirmed from the Activity Log, and removed 18 minutes after it was made.

## Timeline (UTC)
| Time | Event |
|---|---|
| 08:47 | Contributor assigned to grp-flagship-auditors (role assignment WRITE) |
| 09:00 | Detected with query 002 (role assignment changes) |
| 09:01 | Analysed: requestbody on the Start event showed RoleDefinitionId = Contributor, PrincipalType = Group; PrincipalId matched grp-flagship-auditors in Entra ID |
| 09:05 | Contained: role assignment removed (role assignment DELETE) |
| 09:17 | Recovery verified: DELETE event in logs; Check access shows Sam Patel with Reader only on the RG |

## Analysis
- Who: subscription owner account (Caller, redacted)
- What: Contributor role (built-in ID b24988ac-6180-42a0-ab88-20f7382dd24c)
- To whom: grp-flagship-auditors (external auditors)
- Where: resource group rg-flagship-lab-uaen
- Impact if not caught: auditors could create, change or delete resources in the project, beyond their read-only job.
- Context: 5 other role assignments that day matched planned lab changes; this one did not.

## Detection
sentinel/kql/002-role-assignment-changes.kql, plus an analysis query parsing Properties_d.requestbody.
Note: requestbody (role and principal) is only present on the Start event, not the Success event.

## Containment and recovery
Removed the Contributor assignment at 09:05 UTC. Verified with Check access and the DELETE event in AzureActivity.

## Lessons learned
- Detection was manual (running query 002). Next step: turn it into a Sentinel scheduled analytics rule so a role change like this creates an incident automatically, and use a playbook for the response steps (planned for v4).
- Granting a powerful role should need approval. Make Contributor and other privileged roles eligible through PIM (Privileged Identity Management) with justification and approval instead of permanent assignments (planned for v7).
- Log ingestion is not instant. Key Vault logs took over 30 minutes to appear the first time, and Activity Log events about 10-15 minutes. An empty result does not mean nothing happened: check timing, query scope (workspace vs resource group) and both the Start and Success events before concluding.

## MITRE ATT&CK
T1098 Account Manipulation; T1078 Valid Accounts (an authorised account used to grant excess access).
