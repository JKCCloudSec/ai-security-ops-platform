v4 Incident Report — Detect and Investigate
Project: Enterprise AI Security Operations and Cloud Security Platform
Version: v4.0
Analyst: Jobin Kurian Chandy
Date: 5 November 2026
Environment: Isolated home lab, fictional data only. Windows Server 2022 domain controller `WIN-MOOCQMEHMQ7` (`lab.local`), an Ubuntu host `ubuntusyslog`, and a Kali box as the attacker. Logs go into Microsoft Sentinel and Microsoft Defender XDR.
I ran three attacks against this lab, built a detection for each, and then investigated what fired. Everything below happened inside the isolated lab network. No TransCore or customer systems were touched, and the only accounts and data involved are made up.
Summary
Three things an attacker commonly does, and what happened when I tried them here:
Guessing one password across many accounts (a password spray) against the domain controller. Detected. It failed — no account was broken into.
A hidden, obfuscated PowerShell command, the kind used to pull code off the internet and run it from memory. Detected, and Defender blocked it on its own before it could run.
Creating a scheduled task so the attacker's code would come back after a reboot (persistence). Detected. I removed the test task afterwards.
None of the three got anywhere. The detail for each is below, with the queries and the investigation steps.
The attacks and detections
#	Attack	MITRE	Where the data lives	Detection built as	Outcome
007	SSH brute force (Linux)	T1110	`Syslog`	Sentinel analytics rule	Detected, failed
008	Password spray (Windows AD)	T1110.003	`SecurityEvent` 4625	Sentinel analytics rule	Detected, failed
009a	PowerShell download/encoded command	T1059.001	`DeviceProcessEvents`	Defender custom detection	Detected and blocked by Defender
009b	Scheduled task persistence	T1053.005	`DeviceProcessEvents`	Defender custom detection	Detected, task removed
One thing I learned building these: the detection engine depends on where the logs are. Logon and syslog events sit in the Log Analytics workspace, so those are Sentinel analytics rules. Endpoint process events sit in Defender XDR, so those are Defender custom detection rules. Same job, different place to build it.
Incident A: password spray on the domain controller (T1110.003)
Severity: Medium. Verdict: true positive, but it failed.
If a spray like this works, the attacker gets a real domain account and a foothold in Active Directory, which is the start of moving sideways and climbing privileges. Because it's an identity attack, the exposure is everything those accounts can reach, not just one machine. That's why I didn't treat it as low severity even though the volume was small.
Timing (lab time):
Step	Time	Target	Met?
Attack run	13:06	—	—
Rule fired, incident #21 raised	13:30	detect within one rule cycle	yes
Verdict reached	~13:40	triage within 30 min	yes
Source block recommended	same session	contain within 1 hour	yes
Time to detect was one 5-minute rule cycle after the attack window.
How it was detected. The Sentinel rule groups failed logons (event 4625) by source IP and counts how many different accounts each source failed against. It alerts when one source hits five or more. That count is what separates a spray (one password, many accounts) from a brute force (many passwords, one account), which is the rule I wrote for 007.
What I found. One source, `192.168.56.104`, failed against eight different accounts on the DC (`jsmith, agarcia, mnoor, rkhan, dsouza, fhassan, bpatel, kishore`) inside a few minutes. The next question is the only one that matters: did any of them actually work?
Checking for a hit. I looked for a successful logon (event 4624) from that same source. The first version of that check returned rows, which looked alarming, but they were all `NT AUTHORITY\ANONYMOUS LOGON`. Those are the null SMB sessions the spray tool opens before it even tries a password, not a real sign-in. Once I filtered out `ANONYMOUS LOGON` and machine accounts (names ending in `$`), there were no successful logons at all. So the spray failed.
Doing this without knowing the account list. In the lab I knew the usernames because I was the attacker. In a real SOC you won't. You don't need them: the pattern of a spray that worked is one source failing against many accounts and then succeeding on one of them. My detection already collects the attempted accounts into an `AccountsTried` field from the attack's own events, and the follow-up query joins each source's failures to any later success from that same source. No prior knowledge needed. The same idea works against `SigninLogs` or Entra audit logs if the attack is against cloud identities instead of on-prem AD.
Containment and after. Block the source IP, keep an eye on the targeted accounts. No password resets, because nothing authenticated. Nothing to eradicate or recover since there was no foothold.
Incident B: PowerShell execution and scheduled task persistence (T1059.001, T1053.005)
This one reads as a short chain on one host: run some hidden PowerShell, then set up persistence.
Severity: High (Defender's own classification). Verdict: true positive, execution prevented.
Timing (lab time):
Step	Time	Note
Obfuscated/encoded PowerShell run	17:35–17:46	download cradle, then an encoded command
Defender detected and blocked	17:35	incident #23, High, "ClickFix malware in a command line was prevented from executing"
Scheduled task created	~18:02	`schtasks /create ... LabPersistTest`
Task detected and removed	18:16	deleted with `schtasks /delete`
What caught the PowerShell. Three things, which is worth noting because it shows the layers. First, AMSI and antivirus blocked the raw download cradle (`IEX (New-Object Net.WebClient).DownloadString(...)`) outright — the command came back "Access is denied." Second, Defender's behavioural side raised a High incident, #23, and labelled it ClickFix, which is the current trick of fooling a user into pasting and running a PowerShell cradle themselves. Third, my own custom detection on `DeviceProcessEvents` caught the encoded command.
Keeping the detection clean. My PowerShell rule keys on the arguments, not the program name, because `powershell.exe` runs constantly for legitimate reasons. When I checked the results, the rule returned only the one encoded command I ran. It correctly ignored my harmless `Write-Host hello` test and the Azure Arc agent's own routine PowerShell (the `gc_arc_service.exe` heartbeat scripts), which is exactly the kind of noise a rule keyed on "powershell ran" would drown in.
The persistence step. The scheduled-task detection showed `schtasks.exe /create ... /tr calc.exe`, and the parent process was `powershell.exe`. That PowerShell-to-schtasks chain is the tell. An installer or an admin creating a task looks different from one spawned out of a PowerShell session.
Containment and after. Execution was already stopped by Defender. I deleted the test task and confirmed with `schtasks /query` that nothing was left behind.
One honest note: because Defender already detects the ClickFix pattern natively, my custom PowerShell rule overlaps it. In a real environment I'd check for native coverage before adding a custom rule, to avoid two alerts for the same thing. I kept it here to practise building a Defender custom detection, and it still earns its place for audit-only or non-blocked variants.
AI-assisted triage, and where I overrode it
I built a small triage helper earlier in this portfolio (Project 3, `soc-alert-triage`). It reads a Sentinel incident and asks Claude for a first-pass draft: a one-line summary, a lean with a confidence level, a couple of things to check, and what information it's missing. It never closes or confirms an incident. It only drafts, and a human decides.
The point I want to make with incident #21 is about the limits of that draft. The tool only sees the incident's own fields — title, severity, MITRE tactic, alert count. The things that actually settled the verdict were things it couldn't see from those fields:
The source was my own Kali box, so I knew this was a test rather than an unknown attacker. The incident record has no way to know that.
I checked for a successful logon from the source and found none, so the spray failed. That check lives outside the incident fields.
The 4624 rows that did come back were `ANONYMOUS LOGON` from the SMB handshake, not real sign-ins. A draft that took "any 4624 from the source" at face value would have flagged a possible compromise that wasn't there.
So my decision: I'd agree with a true-positive lean, but override anything suggesting a possible compromise. Final call, failed spray, nothing broken into. This is the reason the tool is built to flag what it's missing rather than sound confident — a confident wrong draft is more dangerous than an honest "I can't tell from here." (If I want the tool's actual draft text in here later, I can run it live and paste it.)
Runbooks
Password spray (T1110.003)
Confirm one source failing against five or more different accounts.
Check for a hit: any 4624 from that source on a sprayed account, after dropping `ANONYMOUS LOGON` and machine (`$`) accounts.
No hit: block the source, watch the accounts, close as true-positive-failed. Hit: escalate, reset that account, kill its sessions.
Why the threshold is five, not two: shared gateways and jump hosts can produce two failed accounts from one IP in an hour just from people mistyping. Five from one source is much harder to explain innocently.
Suspicious PowerShell (T1059.001)
Confirm a real signal in the command line: `-enc`, `DownloadString`, `Net.WebClient`, `IEX`, `FromBase64String`.
Look at the parent process. PowerShell launched by Office, wscript or cmd is far more suspicious than an admin's own shell.
Decode any `-enc` payload to see what it actually does.
`-nop` and `hidden` on their own are weak — plenty of real scripts use them — so they aren't the trigger, only supporting context.
Scheduled task persistence (T1053.005)
Confirm `schtasks /create` or a `Register-ScheduledTask`/`New-ScheduledTask` call.
Read the task's action. Pointing at `powershell`, an encoded blob, `cmd /c`, a temp folder or a URL is the bad case. `calc.exe` or a known installer usually isn't.
Check who created it and what the parent process was.
`schtasks /create` is common for admins and installers, so on its own it's medium confidence. Tighten it by requiring a suspicious task action.
Shift handover
v4 attacks done. Password spray (#21, true positive, failed, source `192.168.56.104` to block). PowerShell/ClickFix (#23, High, blocked by Defender). Scheduled task persistence detected and the test task deleted.
Four detections live across 007–009. The custom PowerShell rule overlaps Defender's native ClickFix detection — flagged in case we want to dedupe.
No open compromise, no resets needed, nothing left running on the DC.
Files
Analytics rules and KQL for 007 and 008 under `sentinel/`.
Custom detections and KQL for 009 under `defender/`.
Screenshots under `docs/v4/img/`, with subscription, tenant and object IDs and email addresses blurred.
