
<#
Remove-ADEmptyGroups

.SYNOPSIS

This script searches for empty Active Directory groups and deletes them based on their creation date.

.Revisions
    Author: Paulo Schwab Rocha
    Creation date: 17-Aug-2020

    Version: 0.1

    Changes:



#>

param (
    [Parameter(ValueFromPipeline = $true, 
        Mandatory = $false)]
    [string]$Global:daysToSendAlert = 40,
    [Parameter(ValueFromPipeline = $true, 
        Mandatory = $false)]
    [string]$Global:daysToDelete = 60,
    [Parameter(ValueFromPipeline = $true, 
        Mandatory = $false)]
    [string]$Global:ExceptionListPath = ".\ExceptionList.txt",
    [Parameter(ValueFromPipeline = $true, 
        Mandatory = $false)]
    [string]$Global:LogPath = $PSScriptRoot
)

Push-Location $PSScriptRoot
$ExceptionList = Get-Content $ExceptionListPath

Import-Module activedirectory

# Declaration of variables
$dt_EmptyGroupsNotification = New-Object 'System.Collections.Generic.List[System.Object]'
$dt_EmptyGroupsDeletion = New-Object 'System.Collections.Generic.List[System.Object]'
[PSCustomObject]$GroupsList = @()

# SMTP Settings
$SMPTServer="smtp-norelay"
$From="pschwab@huisman-br.com"
$To="pschwab@huisman-br.com"
$message = New-Object System.Net.Mail.MailMessage $From, $To
$message.Subject = "Empty Groups to be Deleted"
$message.IsBodyHTML = $true

# Exception List
$ExceptionList = Get-Content $ExceptionListPath

# HTML Style
$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
$style = $style + "TD{border: 1px solid black; padding: 5px; }"
$style = $style + "</style>"

# Command to Search and Filter empty AD Groups
$EmptyADGroups = Get-ADGroup -Filter * -Properties Members,whenCreated | Where {-not $_.members} | select Name, whenCreated

foreach ($emptyGroup in $EmptyADGroups){

    if ($emptyGroup.Name -notin $ExceptionList){

        # Function to send information only about the groups that are empty and created before $daysToSendAlert value.
        if($emptyGroup.whenCreated -lt (Get-Date).AddDays(-$daysToSendAlert)){
            
            # Add content to the table to create the report
            $GroupsList = [PSCustomObject]@{
                'Name' = $emptyGroup.Name
                'Creation Date' = $emptyGroup.whenCreated.ToString("dd/MMM/yy")
            }

            $dt_EmptyGroupsNotification.Add($GroupsList)
        }
        
        # Function to DELETE the groups that are empty and created before $daysToDelete value.
        if($emptyGroup.whenCreated -lt (Get-Date).AddDays(-$daysToDelete)){
            
            # Deletes the Group from Active Directory
            #Remove-ADGroup $emptyGroup.Name -Confirm:$false
            
            # Add content to the table to create the report
            $GroupsList = [PSCustomObject]@{
                'Name' = $emptyGroup.Name
                'Creation Date' = $emptyGroup.whenCreated.ToString("dd/MMM/yy")
            }

            $dt_EmptyGroupsDeletion.Add($GroupsList)
        }
    }

}

# Save Log File
$CurrentDate = (Get-date).ToString("ddMMyyyy")
$dt_EmptyGroupsNotification | Out-File ".\Notification-$CurrentDate.log" -Append utf8
$dt_EmptyGroupsDeletion | Out-File ".\DeletedGroups-$CurrentDate.log" -Append utf8

# Email message Body
$message.Body = "Dears, <br><br>
The following groups are empty and were created more than "+ $daysToSendAlert +" days:<br>
These groups <b>will be deleted</b> if they are empty for longer than "+ $daysToDelete + " days.<br><br>"+
 ($dt_EmptyGroupsNotification | ConvertTo-Html -Head $style) +"<br><br>
 If these groups are still necessary, please add users or groups to it, and/or add the Group to the Exception List.<br><br><br>
 <br>-------------------------------------------------------------------<br><br>
 The following groups have been <b>DELETED</b> as they were empty and created more than "+ $daysToDelete + " days ago: <br><br>
 " + ($dt_EmptyGroupsDeletion | ConvertTo-Html -Head $style) + "<br><br>
 If any of these groups are still needed, request a restore.<br>"

# Sends Email message
$smtp = New-Object Net.Mail.SmtpClient($SMPTServer)
$smtp.Send($message)
