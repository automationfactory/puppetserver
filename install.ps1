# install.ps1 : This powershell script installs the puppet-agent package from a Puppet Enterprise master
# you could call this script like this:
# install.ps1 [-UsePuppetCA] main:certname=foo custom_attributes:challengePassword=SECRET extension_requests:pp_role=webserver
#
# By default, the script will start and enable the puppet agent service after installation.
# To change that behavior, set the PuppetServiceEnsure and/or PuppetServiceEnable parameters.
#  Example:  install.ps1 -PuppetServiceEnsure stopped -PuppetServiceEnable false
#
# This script supports passing in a limited set of MSI properties as script parameters.
[CmdletBinding()]

Param(
  [Switch]$UsePuppetCA,
  [String]$InstallDir,
  [String]$PuppetAgentAccountUser,
  [String]$PuppetAgentAccountPassword,
  [String]$PuppetAgentAccountDomain,
  [ValidateSet("running","stopped")] [String] $PuppetServiceEnsure = "running",
  [ValidateSet("true","false","manual")] [String] $PuppetServiceEnable = "true",
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [String[]]
  # This value would be $null when no parameters are passed in; however, a PS2 bug causes foreach to iterate once
  # over $null, which is undesirable. Setting the default to an empty array gets around that PS2 bug.
  $arguments = @()
)
# If an error is encountered, the script will stop instead of the default of "Continue"
$ErrorActionPreference = "Stop"

$server          = 'puppet.c.prefab-pixel-185310.internal'
$port            = '8140'
$puppet_bin_dir  = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Puppet Labs\Puppet\bin'
$puppet_conf_dir = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Puppetlabs\puppet\etc'
$date_time_stamp = (Get-Date -format s) -replace ':', '-'
$install_log     = Join-Path ([System.IO.Path]::GetTempPath()) "$date_time_stamp-puppet-install.log"
$cert_path       = Join-Path $puppet_conf_dir 'ssl\certs\ca.pem'

# Start with assumption of 64 bit agent package unless probe detects 32 bit.
$arch       = 'x64'
$msi_path   = 'windows-x86_64'
if ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -match '^32') {
  $arch     = 'x86'
  $msi_path = 'windows-i386'
}
$msi_source    = "https://${server}:$port/packages/current/$msi_path/puppet-agent-$arch.msi"
$msi_dest      = Join-Path ([System.IO.Path]::GetTempPath()) "puppet-agent-$arch.msi"
$class_arch    = $msi_path -replace '-', '_'
$pe_repo_class = "pe_repo::platform::$class_arch"

function GetMSIProperties {
  # Search for any MSI properties to use, and construct and return a string to pass to the msiexec command.

  $MSIProps = $null

  if ($InstallDir) {
    Write-Verbose "Using MSI property INSTALL_DIR: ${InstallDir}"
    $MSIProps += "INSTALL_DIR=${InstallDir} "
  }

  if ($PuppetAgentAccountUser) {
    Write-Verbose "Using MSI property PUPPET_AGENT_ACCOUNT_USER: ${PuppetAgentAccountUser}"
    $MSIProps += "PUPPET_AGENT_ACCOUNT_USER=${PuppetAgentAccountUser} "
  }

  if ($PuppetAgentAccountPassword) {
    Write-Verbose "Using MSI property PUPPET_AGENT_ACCOUNT_PASSWORD: [REDACTED]"
    $MSIProps += "PUPPET_AGENT_ACCOUNT_PASSWORD=${PuppetAgentAccountPassword} "
  }

  if ($PuppetAgentAccountDomain) {
    Write-Verbose "Using MSI property PUPPET_AGENT_ACCOUNT_DOMAIN: ${PUPPET_AGENT_ACCOUNT_DOMAIN}"
    $MSIProps += "PUPPET_AGENT_ACCOUNT_DOMAIN=${PuppetAgentAccountDomain} "
  }

  # Set MSI properties that are required by this pe_repo simplified installer.
  # These are explicitly not exposed to the user to reduce the chance of having duplicated settings.
  # PUPPET_MASTER_SERVER should be controlled by the pe_repo class's 'server' parameter.
  # PUPPET_AGENT_STARTUP_MODE needs to be Manual so pe_repo can better control the first Puppet run.
  $MSIProps += "PUPPET_MASTER_SERVER=${server} "
  $MSIProps += "PUPPET_AGENT_STARTUP_MODE=Manual "

  $MSIProps
}

function CustomPuppetConfiguration {
  # Parse optional pre-installation configuration of Puppet settings via
  # command-line arguments. Arguments should be of the form
  #
  #   <section>:<setting>=<value>
  #
  # There are four valid section settings in puppet.conf: "main", "master",
  # "agent", "user". If you provide valid setting and value for one of these
  # four sections, it will end up in <confdir>/puppet.conf.
  #
  # There are two sections in csr_attributes.yaml: "custom_attributes" and
  # "extension_requests". If you provide valid setting and value for one
  # of these two sections, it will end up in <confdir>/csr_attributes.yaml.
  #
  # note:Custom Attributes are only present in the CSR, while Extension
  # Requests are both in the CSR and included as X509 extensions in the
  # signed certificate (and are thus available as "trusted facts" in Puppet).
  #
  # Regex is authoritative for valid sections, settings, and values.  Any input
  # that fails regex will trigger this script to fail with error message.
  $regex = '^(main|master|agent|user|custom_attributes|extension_requests):(.+?)=(.*)$'
  $attr_array = @()
  $extn_array = @()
  $match = $null

  foreach ($entry in $arguments) {
    if (! ($match = [regex]::Match($entry,$regex)).Success) {
      Throw "Unable to interpret argument: '$entry'. Expected '<section>:<setting>=<value>' matching regex: '$regex'"
    }
    else {
      $section = $match.groups[1].value
      $setting = $match.groups[2].value
      $value   = $match.groups[3].value
      switch ($section) {
        'custom_attributes' {
          # Store the entry in attr_array for later addition to csr_attributes.yaml
          $attr_array += "${setting}: '${value}'"
          break
        }
        'extension_requests' {
          # Store the entry in extn_array for later addition to csr_attributes.yaml
          $extn_array += "${setting}: '${value}'"
          break
        }
        default {
          # Set the specified entry in puppet.conf
          Write-Verbose "Setting Puppet config option: ${section}:${setting}=${value}"
          & $puppet_bin_dir\puppet config set $setting $value --section $section
          break
        }
      }
    }
  }
  # If the the length of the attr_array or extn_array is greater than zero, it
  # means we have settings, so we'll create the csr_attributes.yaml file.
  if ($attr_array.length -gt 0 -or $extn_array.length -gt 0) {
    Write-Verbose "Creating ${puppet_conf_dir}\csr_attributes.yaml file"
    echo('---') | out-file -filepath $puppet_conf_dir\csr_attributes.yaml -encoding UTF8

    if ($attr_array.length -gt 0) {
      echo('custom_attributes:') | out-file -filepath $puppet_conf_dir\csr_attributes.yaml -append -encoding UTF8
      for ($i = 0; $i -lt $attr_array.length; $i++) {
        Write-Verbose "Setting custom_attribute: $($attr_array[$i])"
        echo('  ' + $attr_array[$i]) | out-file -filepath $puppet_conf_dir\csr_attributes.yaml -append -encoding UTF8
      }
    }

    if ($extn_array.length -gt 0) {
      echo('extension_requests:') | out-file -filepath $puppet_conf_dir\csr_attributes.yaml -append -encoding UTF8
      for ($i = 0; $i -lt $extn_array.length; $i++) {
        Write-Verbose "Setting extenstion_requests: $($extn_array[$i])"
        echo('  ' + $extn_array[$i]) | out-file -filepath $puppet_conf_dir\csr_attributes.yaml -append -encoding UTF8
      }
    }
  }
}

$callback = {
  param(
      $sender,
      [System.Security.Cryptography.X509Certificates.X509Certificate]$certificate,
      [System.Security.Cryptography.X509Certificates.X509Chain]$chain,
      [System.Net.Security.SslPolicyErrors]$sslPolicyErrors
  )

  $CertificateType = [System.Security.Cryptography.X509Certificates.X509Certificate2]

  # Read the CA cert from file
  $CACert = $CertificateType::CreateFromCertFile($cert_path) -as $CertificateType

  # Add cert to collection of certificates that is searched by
  # the chaining engine when validating the certificate chain.
  $chain.ChainPolicy.ExtraStore.Add($CACert) | Out-Null

  # Compare the cert on disk to the cert from the server
  $chain.Build($certificate) | Out-Null

  # If the first status is UntrustedRoot, then it's a self signed cert
  # Anything else in this position means it failed for another reason
  return $chain.ChainStatus[0].Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::UntrustedRoot
}

function DownloadPuppet {
  Write-Verbose "Downloading the Puppet Agent for Puppet Enterprise on $env:COMPUTERNAME..."

  # Pass in a function to validate the cert. {$true} means validate any cert.
  if ($UsePuppetCA -And (!(Test-Path $cert_path))) {
    Throw "UsePuppetCA was requested but no CA certificate found at $cert_path"
  } elseif ($UsePuppetCA -Or (Test-Path $cert_path)) {
    Write-Verbose "Using found Puppet CA certificate to validate the Puppet Agent download: $cert_path"
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $callback
  } else {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  }

  # Create the webclient object with the desired callback defined above.
  $webclient = New-Object system.net.webclient

  try {
    $webclient.DownloadFile($msi_source,$msi_dest)
  }
  catch [System.Net.WebException] {
    # If we can't find the msi, then we may not be configured correctly
    if($_.Exception.Response.StatusCode -eq [system.net.httpstatuscode]::NotFound) {
        Throw "Failed to download the Puppet Agent installer: $msi_source. Does the Puppet Master have the $pe_repo_class class applied to it?"
    }

    # Throw all other WebExceptions in case the cert did not validate properly
    Throw $_
  }
}

function InstallPuppet {
  $MSIProperties = GetMSIProperties
  $msiexec_args = "/qn /log $install_log /i $msi_dest $MSIProperties"
  Write-Output "Saving the install log to $install_log"
  Write-Output "Installing the Puppet Agent on $env:COMPUTERNAME..."
  $msiexec_proc = [System.Diagnostics.Process]::Start('msiexec', $msiexec_args)
  $msiexec_proc.WaitForExit()
  if (@(0, 1641, 3010) -NotContains $msiexec_proc.ExitCode) {
    Throw "Something went wrong with the installation on $env:COMPUTERNAME. Exit code: " + $msiexec_proc.ExitCode + ". Check the install log at $install_log"
  }
  $certname = & $puppet_bin_dir\puppet config print certname
  & $puppet_bin_dir\puppet config set certname $certname --section main
}

function ManagePuppetService {
  Write-Verbose "Setting the Puppet Agent service to ensure=$PuppetServiceEnsure and enable=$PuppetServiceEnable"
  & $puppet_bin_dir\puppet resource service puppet ensure=$PuppetServiceEnsure enable=$PuppetServiceEnable
}

DownloadPuppet
InstallPuppet
CustomPuppetConfiguration
ManagePuppetService
Write-Output "Installation has completed."
