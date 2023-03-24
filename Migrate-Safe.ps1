$Source = "https://oneconnection.intra.corp/"
$Destination = "https://oneconnection.pre.intra.corp/"
$SourceSafeName = "adm203544"
#Connections 
$SourceCredential = $(Get-Credential -message "Please provide Credential for source : $Source")
$DestinationCredential = $(Get-Credential -message "Please provide Credential for Destination : $Destination")
New-PASSession -BaseURI $Source -Credential $SourceCredential
$SourceToken = Get-PASSession
New-PASSession -BaseURI $Destination -Credential $DestinationCredential
$DeestinationToken = Get-PASSession

#Safe Migration
Use-PASSession -Session $SourceToken
Start-Sleep 1
$SourceSafe = Get-PASSafe -SafeName $SourceSafeName -ErrorAction SilentlyContinue
if ($SourceSafe) {
    $SourceSafeMember = Get-PASSafeMember -SafeName  $SourceSafeName
    $SourceAccounts = Get-PASAccount -safeName $SourceSafeName
    $SourceAccountsPasswords = $SourceAccounts | ForEach-Object { Get-PASAccountPassword -AccountID $_.id }
}else{
    Write-Host "$SourceSafeName not found on $Source"
}

Use-PASSession -Session $DeestinationToken
Start-Sleep 1
$DestinationSafe = Get-PASSafe -SafeName $SourceSafeName -ErrorAction SilentlyContinue
if ($DestinationSafe) {
    Write-Host "$SourceSafeName already exist on $Destination"

}
else {
    Write-Host "$SourceSafeName not found on $Destination"
    Write-Host "Creating $SourceSafeName on $Destination"
    $DestinationSafe = Add-PASSafe -SafeName $SourceSafeName -NumberOfDaysRetention $SourceSafe.NumberOfDaysRetention -ManagingCPM $SourceSafe.ManagingCPM
}

if($DestinationSafe){
    Write-Host "Adding Member for $SourceSafeName on $Destination"
    foreach($Member in $SourceSafeMember){
        $Member.Permissions | Set-PASSafeMember -SafeName $DestinationSafe.SafeName -MemberName $Member.UserName 
    }
}
#Account Migration
foreach($SourceAccount in $SourceAccounts){
    $Account = Get-PASAccount -safeName $DestinationSafe.SafeName -search $SourceAccount.userName  | Where-Object {$_.Unsername -eq $SourceAccount.userName}
    if($Account){
        Write-Host "$($SourceAccount.userName) Already exist on $($DestinationSafe.SafeName)"
    }else{
        $Account = Add-PASAccount -address $SourceAccount.address -userName $SourceAccount.userName -platformID $SourceAccount.platformId -SafeName $DestinationSafe.SafeName -automaticManagementEnabled $SourceAccount.secretManagement.automaticManagementEnabled
        $ClearAccountPassword= $SourceAccountsPasswords | Where-Object {$_.userName -eq $SourceAccount.userName }
        $SecPassword = ConvertTo-SecureString $ClearAccountPassword -AsPlainText -Force
        Invoke-PASCPMOperation -AccountID $Account.id -ChangeTask -NewCredentials $SecPassword
    }
    
}
