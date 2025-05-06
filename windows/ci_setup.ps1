if -not ([Security.Principal.WindowsPrincipal] `
 [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) {
    throw "Must run with admin rights"
}

if (-not (Get-Command -ea ignore sshd)) {
    dism /online /add-capability /capabilityname:OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
        Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    } else {
        Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
    }
}

$ssh_authorized_file = "C:\ProgramData\ssh\administrators_authorized_keys"
if (-not (Test-Path $ssh_authorized_file)) {
    New-Item $ssh_authorized_file -Type File

    # https://superuser.com/a/1531769
    $acl = Get-Acl C:\ProgramData\ssh\administrators_authorized_keys
    $acl.SetAccessRuleProtection($true, $false)
    $administratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule("Administrators","FullControl","Allow")
    $systemRule = New-Object system.security.accesscontrol.filesystemaccessrule("SYSTEM","FullControl","Allow")
    $acl.SetAccessRule($administratorsRule)
    $acl.SetAccessRule($systemRule)
    $acl | Set-Acl
}

if (-not (Get-Command -ea ignore java)) {
    winget install Microsoft.OpenJDK.21
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

if (-not (Test-Path C:\jenkins-msys2)) {
    winget install MSYS2.MSYS2 --location C:\jenkins-msys2
}

winget install -e --id Python.Python.3.10
