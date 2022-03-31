# Multithreaded-ExhangeOnline

It's (currently) possible to have a maximum of three Exchange Online connections alive simultaneously using ExchangeOnlineManagement. While piped cmdlets (e.g. "get-mailbox | Get-MailboxFolderPermission) do multiprocess in the backend (according to Microsoft docs), it would be even faster to use three connections at once. This is an implementation that achieves this.

For the easiest customization, change the commands after the "Customize from here" comment.

There's 2 files: 

- ParralelExhangeOnlineManagementCommand.ps1
  - Script containing actual functions implementing multithreading ExchangeOnlineManagement
- PerformanceTest.ps1:
  - Serves as a usage example, implementing "Get-Mailbox | Get-MailboxFolderPermission" in parallel
  - Checks how many seconds it takes to perform the scriptblock serially, and then in parralel
