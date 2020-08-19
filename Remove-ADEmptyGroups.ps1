<#
Remove-ADEmptyGroups

.SYNOPSIS

This script searches for empty Active Directory groups and deletes them based on their creation date.

.Revisions
    Author: Paulo Schwab Rocha
    Creation date: 17-Aug-2020

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
    [array]$Global:ExceptionList = $PSScriptRoot+"\ExceptionList.txt",
    [Parameter(ValueFromPipeline = $true, 
        Mandatory = $false)]
    [string]$Global:LogPath = $PSScriptRoot+"\DeleteGroups.log"
)

Import-Module activedirectory

# Command to Search and Filter empty AD Groups
$EmptyADGroups = Get-ADGroup -Filter * -Properties Members,whenCreated | Where {-not $_.members} | select Name, whenCreated

foreach ($emptyGroup in $EmptyADGroups){

    if ($emptyGroup -notin $ExceptionList){
        if($emptyGroup.whenCreated -lt (Get-Date).AddDays(-$daysToSendAlert)){
            $emptyGroups += $emptyGroup.Name
        }
    }

}
