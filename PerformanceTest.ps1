# Start a single exchange session to get mailboxes to process. Session will be re-used when
# running in parallel.
if ((Get-PSSession | where -Property ConfigurationName -eq "Microsoft.Exchange") -eq $null) {
    Connect-ExchangeOnline
}
$session = (Get-PSSession | where -Property ConfigurationName -eq "Microsoft.Exchange")[0]

# Collection of mailboxes to perform a multithreaded operation on
$mailboxes = Get-Mailbox

# Function that will run in parallel
. .\ParralelExhangeOnlineManagementCommand.ps1

$scriptblock = {
    Param (
        $session, # Always keep this as the first argument when customizing the scriptblock, an arbitrary amount of args can come after
        $mailboxes_to_process
    )
    foreach ($mailbox in $mailboxes_to_process) {
        write-output (invoke-command -session $session -ScriptBlock {
        param($ident) 
        # Customize from here for quick & easy customization
        Get-MailboxFolderPermission $ident
        # Until here
        } -ArgumentList ($mailbox.userprincipalname))
        
    }
}

# Create a number of lists equal to amount of threads, splitting up mailboxes between them
$Mailbox_chunks = Split-Array -inArray $Mailboxes -numberOfChunks $number_of_threads

# Implement a serial run function for baseline performance
function RunNormal {
    Invoke-Command -ScriptBlock $scriptblock -ArgumentList $session, $mailboxes
}

$normal = (Measure-Command {RunNormal})
Write-Output "Serial run: $($normal.TotalSeconds) seconds"
$parellel = (measure-command {Run-ParallelExchangeOnlineCommand -scriptblock $scriptblock -ArgumentList @($Mailbox_chunks.Values)})
Write-Output "Parallel run: $($parellel.TotalSeconds) seconds"
