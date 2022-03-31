function Run-ParallelExchangeOnlineCommand {
    <#
    .SYNOPSIS
    Run a scriptblock containing ExchangeOnlineManagement commands in parrelel by using multiple sessions.
    .DESCRIPTION
    Run a scriptblock containing ExchangeOnlineManagement commands in parrelel by using multiple sessions.
    The maxmimum amount of sessions is currently three, so performance for large batches of commands can be 3x'd.
    .PARAMETERS
    - ScriptBlock: A scriptblock to run for each thread/argument pair
    - ArgumentList: List of aguments, size equal to number of threads. Each thread receives 1 argument. Argument should
    probably be a list itself, contaning e.g. mailboxes to run on. So if you have 100 mailboxes and 3 threads, slice mailbox list
    into 3 lists, and pass those 3 lists as the ArgumentList parameter.
    .EXAMPLE
    Run-ParralelExchangeOnlineCommmand `
        -ScriptBlock {
        Param (
        $session, # Always keep this as the first argument when customizing, an arbitrary amount of args can come after
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
     } `
        -ArgumentList @(@(1@eg.com, 2@eg.com), @(3@eg.com, 4@eg.com),
        @(5@eg.com, 6@eg.com))
    #>
    param (
        $ScriptBlock,
        $ArgumentList
    )
    $number_of_threads = 3  # This is the current maximum number of Office365 connections

    # Connect to Exchange the maximum amount of times
    while ((Get-PSSession | where -Property ConfigurationName -eq "Microsoft.Exchange" | measure).count -ne $number_of_threads) {
        1..$number_of_threads | % {
            Connect-ExchangeOnline
        }
    }
    $sessions = Get-PSSession | where -Property ConfigurationName -eq "Microsoft.Exchange" 

    $pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
    $pool.ApartmentState = "MTA"
    $pool.Open()
    $runspaces = @()

    # Start the threads
    0..($number_of_threads - 1) | ForEach-Object {
        $runspace = [PowerShell]::Create()
        $null = $runspace.AddScript($scriptblock)
        $null = $runspace.AddArgument($sessions[$_])
        $null = $runspace.AddArgument($ArgumentList[$_])
        $runspace.RunspacePool = $pool
        $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
    }

    # output
    while ($runspaces.Status -ne $null)
    {
        $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
        foreach ($runspace in $completed)
        {
            $runspace.Pipe.EndInvoke($runspace.Status)
            $runspace.Status = $null
        }
    }

    $pool.Close()
    $pool.Dispose()
    }


  
function Split-Array($inArray, $numberOfChunks) {
    <#
    .SYNOPSIS
    Convenience function to split up a list as evenly as possible, outputting to hashtable.
    .DESCRIPTION
    Convenience function to split up a list as evenly as possible, outputting to hashtable.
    .PARAMETERS
    - InArray: Array to split up (Array)
    - NumberOfChunks: Number of output lists (Int)
    .EXAMPLE
    Split-Array -InArray @('a', 'b', 'c') -NumberOfChunks 3
    Output hashtable:
    @{0: 'a', 1: 'b', 2: '3'}
    #>
    $Lists = @{}
    $count = 0 
    0..($numberOfChunks-1) | % {
        $Lists[$_] = New-Object System.Collections.ArrayList
    }

    $inArray | % { 
        [void]$Lists[$count % $numberOfChunks].Add($_); 
        $count++ 
    }

    return $Lists
}
