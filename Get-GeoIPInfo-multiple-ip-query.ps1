#https://gist.github.com/dindoliboon/32d9aa78842d33359c5ce624c570ca96

function Test-RFC1918IPv4Address{
    [cmdletbinding()]
    [outputtype([System.Boolean])]
    param(
        # IP Address to find.
        [parameter(Mandatory,Position=0)]
        [validatescript({
            ([System.Net.IPAddress]$_).AddressFamily -eq 'InterNetwork'
        })]
        [string]$IPAddress
    )

    # Determine whether the address is in the RFC1918 address
    # https://stackoverflow.com/questions/2814002/private-ip-address-identifier-in-regular-expression
    $matches = Select-String -Pattern '(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)' -InputObject $IPAddress

    if(($matches | Measure-Object).Count -gt 0) {
        return $true
    } else {
        return $false
    }
}


$ts_start            = get-date
$ts_start_timestamp      = $ts_start.ToString("yyyyMMddTHHmmssffff")
$ts_start_timestamp_utc  = $ts_start.ToUniversalTime().ToString("yyyyMMddTHHmmssffffZ")

$rfc1918pattern = '(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)'
$netstat = Get-NetTCPConnection -State Established | Select-Object RemoteAddress | Where-Object { $_.RemoteAddress -notlike '*::*' }
$netstat_ip_list = $netstat | Select-Object RemoteAddress -Unique | Where-Object { $_.RemoteAddress -notmatch $rfc1918pattern }

Import-Module $PSScriptRoot/libMaxMindGeoIp2V1.psm1

$maxMindDbDll = "$PSScriptRoot/maxmind.dbreader/net45/MaxMind.Db.dll"
$ipDbIsp      = "$PSScriptRoot/maxmind/GeoLite2-ASN.mmdb"
$GeoIpReader  = New-GeoIp2Reader -Library $maxMindDbDll -Database $ipDbIsp
$IspStat = @{}
$totalRemoteIpv4ConnCount = 0

Write-Output "`n"
ForEach ($my in $netstat_ip_list) {
    $ts_start_ip = get-date
    $RemoteAddress = $my.RemoteAddress

    # PSCustomObject conversion
    $lookupResult = Find-GeoIp2 -Reader $GeoIpReader -IpAddress $RemoteAddress | ConvertTo-Json -Depth 5 | ConvertFrom-Json

    $targetASN   = $lookupResult.autonomous_system_number
    $targetASOrg = $lookupResult.autonomous_system_organization
    $targetConnCount = ($netstat -match $RemoteAddress).Count

    $totalRemoteIpv4ConnCount += $targetConnCount
    if ($IspStat.ContainsKey($targetASOrg)) {
        $IspStat["$targetASOrg"] += $targetConnCount
    } else {
        $IspStat.Add("$targetASOrg", $targetConnCount)
    }

    $ts_end_ip = get-date
    $ts_duration_ip = $ts_end_ip - $ts_start_ip
    $ts_duration_ip_time = "{0:N1}" -f $ts_duration_ip.TotalMilliseconds
    Write-Output "$RemoteAddress`tISP: $targetASOrg ($targetASN)`t $ts_duration_ip_time (ms)"

}
Close-GeoIp2Reader -Reader ([ref]$GeoIpReader)
$IspStat | Format-Table -AutoSize

Write-Output "`nConnections : $totalRemoteIpv4ConnCount"
Write-Output "Timestamp : $ts_start_timestamp"
Write-Output "Timestamp(UTC) : $ts_start_timestamp_utc"

$ts_end = get-date
$ts_duration = $ts_end - $ts_start
$ts_duration_time = "{0:N0}" -f $ts_duration.TotalMilliseconds
Write-Output "`nElapsed time: $ts_duration_time (ms)"

# SIG # Begin signature block
# MIIQLgYJKoZIhvcNAQcCoIIQHzCCEBsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAz32BxaHlfKIrh
# 6Uziyyjnx16o1vSDYwefK/RY+ybSq6CCDXIwggQgMIIDCKADAgECAhA0TtVXINXt
# 7En0L8432yttMA0GCSqGSIb3DQEBBQUAMIGpMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMdGhhd3RlLCBJbmMuMSgwJgYDVQQLEx9DZXJ0aWZpY2F0aW9uIFNlcnZpY2Vz
# IERpdmlzaW9uMTgwNgYDVQQLEy8oYykgMjAwNiB0aGF3dGUsIEluYy4gLSBGb3Ig
# YXV0aG9yaXplZCB1c2Ugb25seTEfMB0GA1UEAxMWdGhhd3RlIFByaW1hcnkgUm9v
# dCBDQTAeFw0wNjExMTcwMDAwMDBaFw0zNjA3MTYyMzU5NTlaMIGpMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMdGhhd3RlLCBJbmMuMSgwJgYDVQQLEx9DZXJ0aWZpY2F0
# aW9uIFNlcnZpY2VzIERpdmlzaW9uMTgwNgYDVQQLEy8oYykgMjAwNiB0aGF3dGUs
# IEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTEfMB0GA1UEAxMWdGhhd3Rl
# IFByaW1hcnkgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AKyg8PuAWdScx6TPnaFZcwkQRQwNLG5o8WxbSGhJWTf8CzMZwnd/zBAtlTQc5utN
# Cacc0rjJlzYCt4nUJF8GwMxElJSNAmJv61rdEY0omlyEkBB6Db10Zi9qOKDi1VRE
# 6x0Hnwe6b+7p/U4LKfU+hKAB8Zyr+Bx+iaToodhxZQ2jUXvuvNIiYA25W53fuvxR
# WwuvmLLpLukE6GKH3ivI107BTGQe3c+HWLpKT8poBx0cnUrG1S+RzHxxchzFwGfr
# Mv3JklyU2oXAm79TfSsJ9IydkR+XalLL3gk2pHfYe4dQRNU+bilp+zlJJh4JpYB7
# QC3r6CeFyf5h/X7mfJcd1Z0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
# HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFHtbRc+vzst6/TGSGmq280brV0hQMA0GCSqG
# SIb3DQEBBQUAA4IBAQB5EcBLs5G2/PDpZ9QNbkW+VeiT0s4DP+3aJbAdV8seOnag
# TOxQduhkcgykqfG4i9bWh4S7MuVBEcB32bNgnesb1dFuRESppgHsVWIdd7hcjkhJ
# fJw7VxGsrXM3ji94XJBoR9lgYOb8Bz0iIBfE9xbpxNhy+chzfN8WLxWpPv1qJ7ah
# 61q6mB/V401kCp0TyGG69Tkch7q4vXsif/b+rEB55awQbz2PG3l2i8Q3syEYhOU2
# AOtjIJm56f4zBLtByMEC+URjIJ6BzkLT1j8sdtNjnFndj6bhDqAuQfculUfPvP0z
# 8/YLYX5+kSuBR8InMO6nEF03j1w5K+QE8HuNVoxoMIIEmTCCA4GgAwIBAgIQcaC3
# NpXdsa/COyuaGO5UyzANBgkqhkiG9w0BAQsFADCBqTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDHRoYXd0ZSwgSW5jLjEoMCYGA1UECxMfQ2VydGlmaWNhdGlvbiBTZXJ2
# aWNlcyBEaXZpc2lvbjE4MDYGA1UECxMvKGMpIDIwMDYgdGhhd3RlLCBJbmMuIC0g
# Rm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxHzAdBgNVBAMTFnRoYXd0ZSBQcmltYXJ5
# IFJvb3QgQ0EwHhcNMTMxMjEwMDAwMDAwWhcNMjMxMjA5MjM1OTU5WjBMMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMdGhhd3RlLCBJbmMuMSYwJAYDVQQDEx10aGF3dGUg
# U0hBMjU2IENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAJtVAkwXBenQZsP8KK3TwP7v4Ol+1B72qhuRRv31Fu2YB1P6uocbfZ4f
# ASerudJnyrcQJVP0476bkLjtI1xC72QlWOWIIhq+9ceu9b6KsRERkxoiqXRpwXS2
# aIengzD5ZPGx4zg+9NbB/BL+c1cXNVeK3VCNA/hmzcp2gxPI1w5xHeRjyboX+NG5
# 5IjSLCjIISANQbcL4i/CgOaIe1Nsw0RjgX9oR4wrKs9b9IxJYbpphf1rAHgFJmkT
# MIA4TvFaVcnFUNaqOIlHQ1z+TXOlScWTaf53lpqv84wOV7oz2Q7GQtMDd8S7Oa2R
# +fP3llw6ZKbtJ1fB6EDzU/K+KTT+X/kCAwEAAaOCARcwggETMC8GCCsGAQUFBwEB
# BCMwITAfBggrBgEFBQcwAYYTaHR0cDovL3QyLnN5bWNiLmNvbTASBgNVHRMBAf8E
# CDAGAQH/AgEAMDIGA1UdHwQrMCkwJ6AloCOGIWh0dHA6Ly90MS5zeW1jYi5jb20v
# VGhhd3RlUENBLmNybDAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYBBQUHAwMwDgYD
# VR0PAQH/BAQDAgEGMCkGA1UdEQQiMCCkHjAcMRowGAYDVQQDExFTeW1hbnRlY1BL
# SS0xLTU2ODAdBgNVHQ4EFgQUV4abVLi+pimK5PbC4hMYiYXN3LcwHwYDVR0jBBgw
# FoAUe1tFz6/Oy3r9MZIaarbzRutXSFAwDQYJKoZIhvcNAQELBQADggEBACQ79deg
# NhPHQ/7wCYdo0ZgxbhLkPx4flntrTB6HnovFbKOxDHtQktWBnLGPLCm37vmRBbmO
# QfEs9tBZLZjgueqAAUdAlbg9nQO9ebs1tq2cTCf2Z0UQycW8h05Ve9KHu93cMO/G
# 1GzMmTVtHOBg081ojylZS4mWCEbJjvx1T8XcCcxOJ4tEzQe8rATgtTOlh5/03XMM
# keoSgW/jdfAetZNsRBfVPpfJvQcsVncfhd1G6L/eLIGUo/flt6fBN591ylV3TV42
# KcqF2EVBcld1wHlb+jQQBm1kIEK3OsgfHUZkAl/GR77wxDooVNr2Hk+aohlDpG9J
# +PxeQiAohItHIG4wggStMIIDlaADAgECAhBoVn/LawJ5wxxFJ25Qn8+LMA0GCSqG
# SIb3DQEBCwUAMEwxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwx0aGF3dGUsIEluYy4x
# JjAkBgNVBAMTHXRoYXd0ZSBTSEEyNTYgQ29kZSBTaWduaW5nIENBMB4XDTE3MDQy
# NzAwMDAwMFoXDTIwMDQyNjIzNTk1OVowazELMAkGA1UEBhMCS1IxFDASBgNVBAgM
# C0d5ZW9uZ2dpLWRvMRQwEgYDVQQHDAtTZW9uZ25hbS1zaTEXMBUGA1UECgwOQmx1
# ZWhvbGUsIEluYy4xFzAVBgNVBAMMDkJsdWVob2xlLCBJbmMuMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEAs2bEaP0uh56EqHv61zOqZVCsENWICdqd9h8U
# g/pGvhY1uqsPUqOZ0TRaxkSIr9BwEz5Cr58h8mnejRtLdExT81w598L2UKn1ZM5M
# YV7oqXgmXkhEFQ51qCTWwDUf5d93aoHdAmJzqTvmp7Nbdji8QIWlw7LWXJum0PBY
# 1g4jVV7MnOBjGJ0ZTRqtadSkzqpy61VdaVEhL6Cl+t3UhQz6w1uFLkeGoaPHheSJ
# Y1uGDVDsE0XauCNP7MVfBn8++By/GREiDxOZMkqZfi6eZDEHNG7vl1lTSJf+mum9
# gxm8fs76KZWM3OtS4Vg8yOPvl4KU3Gc34ezgpjM6Koy1lYGelQIDAQABo4IBajCC
# AWYwCQYDVR0TBAIwADAfBgNVHSMEGDAWgBRXhptUuL6mKYrk9sLiExiJhc3ctzAd
# BgNVHQ4EFgQUP5rY7khjwcGHEu3upP21UTtSF2QwKwYDVR0fBCQwIjAgoB6gHIYa
# aHR0cDovL3RsLnN5bWNiLmNvbS90bC5jcmwwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMG4GA1UdIARnMGUwYwYGZ4EMAQQBMFkwJgYIKwYBBQUH
# AgEWGmh0dHBzOi8vd3d3LnRoYXd0ZS5jb20vY3BzMC8GCCsGAQUFBwICMCMMIWh0
# dHBzOi8vd3d3LnRoYXd0ZS5jb20vcmVwb3NpdG9yeTBXBggrBgEFBQcBAQRLMEkw
# HwYIKwYBBQUHMAGGE2h0dHA6Ly90bC5zeW1jZC5jb20wJgYIKwYBBQUHMAKGGmh0
# dHA6Ly90bC5zeW1jYi5jb20vdGwuY3J0MA0GCSqGSIb3DQEBCwUAA4IBAQBa0lUr
# J6sXXvst+XUaeY5qNvsq2MV8VdappLcgOur07qaFLKv5dBuUg4D+GY52L9Rn5q+n
# 1tbJMA9kqFdBqjt646DR/Wea84/zDGpRDsJqbXpQw9+oh/rMS6CtLRu/6eThVcaA
# E2yNEooXW+NBG5e+Kirwusf4F0ymZxMKgoNqDIavjRKoUu5rFll+lWI+/+TMDSmp
# tbLaWjt+AzS2IqMwoh45uJZpN6qIIatuJvah4vq0NXvm418t6vC8wwjbqbKiaU3/
# /3N4p/cruDwAT4mMEwhRu/zfakt83A+vr1ZIrKclRI9jIz5clyFGfExv9GYgBEbG
# JCi3WNkRApvLnTsaMYICEjCCAg4CAQEwYDBMMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMdGhhd3RlLCBJbmMuMSYwJAYDVQQDEx10aGF3dGUgU0hBMjU2IENvZGUgU2ln
# bmluZyBDQQIQaFZ/y2sCecMcRSduUJ/PizANBglghkgBZQMEAgEFAKCBhDAYBgor
# BgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDL
# O5/FE4wUMjK1u9S+Iid3kCMI34YE6EmvHdzkLElg/DANBgkqhkiG9w0BAQEFAASC
# AQCkuN3y3JR4tUbbzI7apbLMdsLpUlfiDMaijLTGuhuAuoVwfXpn5Y/Ed8MBL5m1
# 7D/i1JjedKJfUq9zhwZCEolrrMrjkEn4mXjGHpYYiK7FXzPKk1BDMjJoq+gCbbHz
# U3kwgz/IfCC1QElPf2fx1cVik6jHw7K6I+VY5Fg8cLbvb98FV3YaBPEf6LXe8M03
# g6vHHcOTS3N2AGHNLlAGO7Lew7w/l6RpmDWWjNVrdf897X9VvDYlD2RztM2DC2AP
# s0WO4zY5v9kuAvScp2wncAdYricNGRnOmR96IK6gW2awPlRwR9UEpSwPGmN65so0
# zfLSik7SLLWmJbb9x002Q1Bm
# SIG # End signature block
