#Requires -version 5.1

# https://www.experts-exchange.com/questions/29131838/Search-CIDR-subnet-ranges-with-powershell.html
function Test-IPInRange {
    [cmdletbinding()]
    [outputtype([System.Boolean])]
    param(
        # IP Address to find.
        [parameter(Mandatory,Position=0)]
        [validatescript({
            ([System.Net.IPAddress]$_).AddressFamily -eq 'InterNetwork'
        })]
        [string]$IPAddress,

        # Range in which to search using CIDR notation. (ippaddr/bits)
        [parameter(Mandatory,Position=1)]
        [validatescript({
            $IP   = ($_ -split '/')[0]
            $Bits = ($_ -split '/')[1]

            (([System.Net.IPAddress]($IP)).AddressFamily -eq 'InterNetwork')

            if (-not($Bits)) {
                throw 'Missing CIDR notiation.'
            } elseif (-not(0..32 -contains [int]$Bits)) {
                throw 'Invalid CIDR notation. The valid bit range is 0 to 32.'
            }
        })]
        [alias('CIDR')]
        [string]$Range
    )

    # Split range into the address and the CIDR notation
    [String]$CIDRAddress = $Range.Split('/')[0]
    [int]$CIDRBits       = $Range.Split('/')[1]

    # Address from range and the search address are converted to Int32 and the full mask is calculated from the CIDR notation.
    [int]$BaseAddress    = [System.BitConverter]::ToInt32((([System.Net.IPAddress]::Parse($CIDRAddress)).GetAddressBytes()), 0)
    [int]$Address        = [System.BitConverter]::ToInt32(([System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes()), 0)
    [int]$Mask           = [System.Net.IPAddress]::HostToNetworkOrder(-1 -shl ( 32 - $CIDRBits))

    # Determine whether the address is in the range.
    if (($BaseAddress -band $Mask) -eq ($Address -band $Mask)) {
        return $true
    } else {
        return $false
    }
}


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

$geoip_isp_db        = Import-Csv -Path $PSScriptRoot/maxmind/GeoLite2-ASN-Blocks-IPv4.csv
$netstat_remote_list = Get-NetTCPConnection -State Established | Where-Object { $_.RemoteAddress -notlike '*::*' } | Sort-Object -Property RemoteAddress | Select-Object RemoteAddress -Unique


Write-Output "`n"
:RemoteAddreLoop ForEach ($my in $netstat_remote_list) {
  $ts_start_ip = get-date
  $RemoteAddress = $my.RemoteAddress

  if (-not(Test-RFC1918IPv4Address -IPAddress $RemoteAddress)) {
    :GeoIPLoop ForEach ($mydb in $geoip_isp_db) {

        $targetCIDR  = $mydb.network
        $targetASN   = $mydb.autonomous_system_number
        $targetASOrg = $mydb.autonomous_system_organization

        if (($RemoteAddress -split '\.')[0] -eq ($targetCIDR -split '\.')[0]) {
            if(Test-IPInRange -IPAddress $RemoteAddress -Range $targetCIDR) {
                $ts_end_ip = get-date
                $ts_duration_ip = $ts_end_ip - $ts_start_ip
                $ts_duration_ip_time = "{0:N1}" -f $ts_duration_ip.TotalMilliseconds

                Write-Output "$RemoteAddress`tISP: $targetASOrg ($targetASN)`t $ts_duration_ip_time (ms)"
                Break :RemoteAddreLoop
            }
        }
    }
  }
}

$ts_end = get-date
$ts_duration = $ts_end - $ts_start
$ts_duration_time = "{0:N0}" -f $ts_duration.TotalMilliseconds

Write-Output "`nElapsed time: $ts_duration_time (ms)"


# SIG # Begin signature block
# MIIa1gYJKoZIhvcNAQcCoIIaxzCCGsMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBHSQ9ubly1Ra5n
# m9NI2qZDN2XsNkvqixmjjfDShPgPrKCCFgswggPuMIIDV6ADAgECAhB+k+v7fMZO
# WepLmnfUBvw7MA0GCSqGSIb3DQEBBQUAMIGLMQswCQYDVQQGEwJaQTEVMBMGA1UE
# CBMMV2VzdGVybiBDYXBlMRQwEgYDVQQHEwtEdXJiYW52aWxsZTEPMA0GA1UEChMG
# VGhhd3RlMR0wGwYDVQQLExRUaGF3dGUgQ2VydGlmaWNhdGlvbjEfMB0GA1UEAxMW
# VGhhd3RlIFRpbWVzdGFtcGluZyBDQTAeFw0xMjEyMjEwMDAwMDBaFw0yMDEyMzAy
# MzU5NTlaMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsayzSVRLlxwS
# CtgleZEiVypv3LgmxENza8K/LlBa+xTCdo5DASVDtKHiRfTot3vDdMwi17SUAAL3
# Te2/tLdEJGvNX0U70UTOQxJzF4KLabQry5kerHIbJk1xH7Ex3ftRYQJTpqr1SSwF
# eEWlL4nO55nn/oziVz89xpLcSvh7M+R5CvvwdYhBnP/FA1GZqtdsn5Nph2Upg4XC
# YBTEyMk7FNrAgfAfDXTekiKryvf7dHwn5vdKG3+nw54trorqpuaqJxZ9YfeYcRG8
# 4lChS+Vd+uUOpyyfqmUg09iW6Mh8pU5IRP8Z4kQHkgvXaISAXWp4ZEXNYEZ+VMET
# fMV58cnBcQIDAQABo4H6MIH3MB0GA1UdDgQWBBRfmvVuXMzMdJrU3X3vP9vsTIAu
# 3TAyBggrBgEFBQcBAQQmMCQwIgYIKwYBBQUHMAGGFmh0dHA6Ly9vY3NwLnRoYXd0
# ZS5jb20wEgYDVR0TAQH/BAgwBgEB/wIBADA/BgNVHR8EODA2MDSgMqAwhi5odHRw
# Oi8vY3JsLnRoYXd0ZS5jb20vVGhhd3RlVGltZXN0YW1waW5nQ0EuY3JsMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIBBjAoBgNVHREEITAfpB0wGzEZ
# MBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMTANBgkqhkiG9w0BAQUFAAOBgQADCZuP
# ee9/WTCq72i1+uMJHbtPggZdN1+mUp8WjeockglEbvVt61h8MOj5aY0jcwsSb0ep
# rjkR+Cqxm7Aaw47rWZYArc4MTbLQMaYIXCp6/OJ6HVdMqGUY6XlAYiWWbsfHN2qD
# IQiOQerd2Vc/HXdJhyoWBl6mOGoiEqNRGYN+tjCCBCAwggMIoAMCAQICEDRO1Vcg
# 1e3sSfQvzjfbK20wDQYJKoZIhvcNAQEFBQAwgakxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwx0aGF3dGUsIEluYy4xKDAmBgNVBAsTH0NlcnRpZmljYXRpb24gU2Vydmlj
# ZXMgRGl2aXNpb24xODA2BgNVBAsTLyhjKSAyMDA2IHRoYXd0ZSwgSW5jLiAtIEZv
# ciBhdXRob3JpemVkIHVzZSBvbmx5MR8wHQYDVQQDExZ0aGF3dGUgUHJpbWFyeSBS
# b290IENBMB4XDTA2MTExNzAwMDAwMFoXDTM2MDcxNjIzNTk1OVowgakxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwx0aGF3dGUsIEluYy4xKDAmBgNVBAsTH0NlcnRpZmlj
# YXRpb24gU2VydmljZXMgRGl2aXNpb24xODA2BgNVBAsTLyhjKSAyMDA2IHRoYXd0
# ZSwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MR8wHQYDVQQDExZ0aGF3
# dGUgUHJpbWFyeSBSb290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEArKDw+4BZ1JzHpM+doVlzCRBFDA0sbmjxbFtIaElZN/wLMxnCd3/MEC2VNBzm
# 600JpxzSuMmXNgK3idQkXwbAzESUlI0CYm/rWt0RjSiaXISQEHoNvXRmL2o4oOLV
# VETrHQefB7pv7un9Tgsp9T6EoAHxnKv4HH6JpOih2HFlDaNRe+680iJgDblbnd+6
# /FFbC6+Ysuku6QToYofeK8jXTsFMZB7dz4dYukpPymgHHRydSsbVL5HMfHFyHMXA
# Z+sy/cmSXJTahcCbv1N9Kwn0jJ2RH5dqUsveCTakd9h7h1BE1T5uKWn7OUkmHgml
# gHtALevoJ4XJ/mH9fuZ8lx3VnQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4G
# A1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUe1tFz6/Oy3r9MZIaarbzRutXSFAwDQYJ
# KoZIhvcNAQEFBQADggEBAHkRwEuzkbb88Oln1A1uRb5V6JPSzgM/7dolsB1Xyx46
# dqBM7FB26GRyDKSp8biL1taHhLsy5UERwHfZs2Cd6xvV0W5ERKmmAexVYh13uFyO
# SEl8nDtXEaytczeOL3hckGhH2WBg5vwHPSIgF8T3FunE2HL5yHN83xYvFak+/Won
# tqHrWrqYH9XjTWQKnRPIYbr1ORyHuri9eyJ/9v6sQHnlrBBvPY8beXaLxDezIRiE
# 5TYA62Mgmbnp/jMEu0HIwQL5RGMgnoHOQtPWPyx202OcWd2PpuEOoC5B9y6VR8+8
# /TPz9gthfn6RK4FHwicw7qcQXTePXDkr5ATwe41WjGgwggSZMIIDgaADAgECAhBx
# oLc2ld2xr8I7K5oY7lTLMA0GCSqGSIb3DQEBCwUAMIGpMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMdGhhd3RlLCBJbmMuMSgwJgYDVQQLEx9DZXJ0aWZpY2F0aW9uIFNl
# cnZpY2VzIERpdmlzaW9uMTgwNgYDVQQLEy8oYykgMjAwNiB0aGF3dGUsIEluYy4g
# LSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTEfMB0GA1UEAxMWdGhhd3RlIFByaW1h
# cnkgUm9vdCBDQTAeFw0xMzEyMTAwMDAwMDBaFw0yMzEyMDkyMzU5NTlaMEwxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwx0aGF3dGUsIEluYy4xJjAkBgNVBAMTHXRoYXd0
# ZSBTSEEyNTYgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAm1UCTBcF6dBmw/wordPA/u/g6X7UHvaqG5FG/fUW7ZgHU/q6hxt9
# nh8BJ6u50mfKtxAlU/TjvpuQuO0jXELvZCVY5YgiGr71x671voqxERGTGiKpdGnB
# dLZoh6eDMPlk8bHjOD701sH8Ev5zVxc1V4rdUI0D+GbNynaDE8jXDnEd5GPJuhf4
# 0bnkiNIsKMghIA1BtwviL8KA5oh7U2zDRGOBf2hHjCsqz1v0jElhummF/WsAeAUm
# aRMwgDhO8VpVycVQ1qo4iUdDXP5Nc6VJxZNp/neWmq/zjA5XujPZDsZC0wN3xLs5
# rZH58/eWXDpkpu0nV8HoQPNT8r4pNP5f+QIDAQABo4IBFzCCARMwLwYIKwYBBQUH
# AQEEIzAhMB8GCCsGAQUFBzABhhNodHRwOi8vdDIuc3ltY2IuY29tMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwMgYDVR0fBCswKTAnoCWgI4YhaHR0cDovL3QxLnN5bWNiLmNv
# bS9UaGF3dGVQQ0EuY3JsMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzAO
# BgNVHQ8BAf8EBAMCAQYwKQYDVR0RBCIwIKQeMBwxGjAYBgNVBAMTEVN5bWFudGVj
# UEtJLTEtNTY4MB0GA1UdDgQWBBRXhptUuL6mKYrk9sLiExiJhc3ctzAfBgNVHSME
# GDAWgBR7W0XPr87Lev0xkhpqtvNG61dIUDANBgkqhkiG9w0BAQsFAAOCAQEAJDv1
# 16A2E8dD/vAJh2jRmDFuEuQ/Hh+We2tMHoeei8Vso7EMe1CS1YGcsY8sKbfu+ZEF
# uY5B8Sz20FktmOC56oABR0CVuD2dA715uzW2rZxMJ/ZnRRDJxbyHTlV70oe73dww
# 78bUbMyZNW0c4GDTzWiPKVlLiZYIRsmO/HVPxdwJzE4ni0TNB7ysBOC1M6WHn/Td
# cwyR6hKBb+N18B61k2xEF9U+l8m9ByxWdx+F3Ubov94sgZSj9+W3p8E3n3XKVXdN
# XjYpyoXYRUFyV3XAeVv6NBAGbWQgQrc6yB8dRmQCX8ZHvvDEOihU2vYeT5qiGUOk
# b0n4/F5CICiEi0cgbjCCBKMwggOLoAMCAQICEA7P9DjI/r81bgTYapgbGlAwDQYJ
# KoZIhvcNAQEFBQAwXjELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENv
# cnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZp
# Y2VzIENBIC0gRzIwHhcNMTIxMDE4MDAwMDAwWhcNMjAxMjI5MjM1OTU5WjBiMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xNDAyBgNV
# BAMTK1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgU2lnbmVyIC0gRzQw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCiYws5RLi7I6dESbsO/6Hw
# YQpTk7CY260sD0rFbv+GPFNVDxXOBD8r/amWltm+YXkLW8lMhnbl4ENLIpXuwitD
# wZ/YaLSOQE/uhTi5EcUj8mRY8BUyb05Xoa6IpALXKh7NS+HdY9UXiTJbsF6ZWqid
# KFAOF+6W22E7RVEdzxJWC5JH/Kuu9mY9R6xwcueS51/NELnEg2SUGb0lgOHo0iKl
# 0LoCeqF3k1tlw+4XdLxBhircCEyMkoyRLZ53RB9o1qh0d9sOWzKLVoszvdljyEmd
# OsXF6jML0vGjG/SLvtmzV4s73gSneiKyJK4ux3DFvk6DJgj7C72pT5kI4RAocqrN
# AgMBAAGjggFXMIIBUzAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMA4GA1UdDwEB/wQEAwIHgDBzBggrBgEFBQcBAQRnMGUwKgYIKwYBBQUHMAGG
# Hmh0dHA6Ly90cy1vY3NwLndzLnN5bWFudGVjLmNvbTA3BggrBgEFBQcwAoYraHR0
# cDovL3RzLWFpYS53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNlcjA8BgNVHR8E
# NTAzMDGgL6AthitodHRwOi8vdHMtY3JsLndzLnN5bWFudGVjLmNvbS90c3MtY2Et
# ZzIuY3JsMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBUaW1lU3RhbXAtMjA0OC0y
# MB0GA1UdDgQWBBRGxmmjDkoUHtVM2lJjFz9eNrwN5jAfBgNVHSMEGDAWgBRfmvVu
# XMzMdJrU3X3vP9vsTIAu3TANBgkqhkiG9w0BAQUFAAOCAQEAeDu0kSoATPCPYjA3
# eKOEJwdvGLLeJdyg1JQDqoZOJZ+aQAMc3c7jecshaAbatjK0bb/0LCZjM+RJZG0N
# 5sNnDvcFpDVsfIkWxumy37Lp3SDGcQ/NlXTctlzevTcfQ3jmeLXNKAQgo6rxS8SI
# KZEOgNER/N1cdm5PXg5FRkFuDbDqOJqxOtoJcRD8HHm0gHusafT9nLYMFivxf1sJ
# PZtb4hbKE4FtAC44DagpjyzhsvRaqQGvFZwsL0kb2yK7w/54lFHDhrGCiF3wPbRR
# oXkzKy57udwgCRNx62oZW8/opTBXLIlJP7nPf8m/PiJoY1OavWl0rMUdPH+S4MO8
# HNgEdTCCBK0wggOVoAMCAQICEGhWf8trAnnDHEUnblCfz4swDQYJKoZIhvcNAQEL
# BQAwTDELMAkGA1UEBhMCVVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5jLjEmMCQGA1UE
# AxMddGhhd3RlIFNIQTI1NiBDb2RlIFNpZ25pbmcgQ0EwHhcNMTcwNDI3MDAwMDAw
# WhcNMjAwNDI2MjM1OTU5WjBrMQswCQYDVQQGEwJLUjEUMBIGA1UECAwLR3llb25n
# Z2ktZG8xFDASBgNVBAcMC1Nlb25nbmFtLXNpMRcwFQYDVQQKDA5CbHVlaG9sZSwg
# SW5jLjEXMBUGA1UEAwwOQmx1ZWhvbGUsIEluYy4wggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQCzZsRo/S6HnoSoe/rXM6plUKwQ1YgJ2p32HxSD+ka+FjW6
# qw9So5nRNFrGRIiv0HATPkKvnyHyad6NG0t0TFPzXDn3wvZQqfVkzkxhXuipeCZe
# SEQVDnWoJNbANR/l33dqgd0CYnOpO+ans1t2OLxAhaXDstZcm6bQ8FjWDiNVXsyc
# 4GMYnRlNGq1p1KTOqnLrVV1pUSEvoKX63dSFDPrDW4UuR4aho8eF5IljW4YNUOwT
# Rdq4I0/sxV8Gfz74HL8ZESIPE5kySpl+Lp5kMQc0bu+XWVNIl/6a6b2DGbx+zvop
# lYzc61LhWDzI4++XgpTcZzfh7OCmMzoqjLWVgZ6VAgMBAAGjggFqMIIBZjAJBgNV
# HRMEAjAAMB8GA1UdIwQYMBaAFFeGm1S4vqYpiuT2wuITGImFzdy3MB0GA1UdDgQW
# BBQ/mtjuSGPBwYcS7e6k/bVRO1IXZDArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8v
# dGwuc3ltY2IuY29tL3RsLmNybDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYI
# KwYBBQUHAwMwbgYDVR0gBGcwZTBjBgZngQwBBAEwWTAmBggrBgEFBQcCARYaaHR0
# cHM6Ly93d3cudGhhd3RlLmNvbS9jcHMwLwYIKwYBBQUHAgIwIwwhaHR0cHM6Ly93
# d3cudGhhd3RlLmNvbS9yZXBvc2l0b3J5MFcGCCsGAQUFBwEBBEswSTAfBggrBgEF
# BQcwAYYTaHR0cDovL3RsLnN5bWNkLmNvbTAmBggrBgEFBQcwAoYaaHR0cDovL3Rs
# LnN5bWNiLmNvbS90bC5jcnQwDQYJKoZIhvcNAQELBQADggEBAFrSVSsnqxde+y35
# dRp5jmo2+yrYxXxV1qmktyA66vTupoUsq/l0G5SDgP4ZjnYv1Gfmr6fW1skwD2So
# V0GqO3rjoNH9Z5rzj/MMalEOwmptelDD36iH+sxLoK0tG7/p5OFVxoATbI0Sihdb
# 40Ebl74qKvC6x/gXTKZnEwqCg2oMhq+NEqhS7msWWX6VYj7/5MwNKam1stpaO34D
# NLYiozCiHjm4lmk3qoghq24m9qHi+rQ1e+bjXy3q8LzDCNupsqJpTf//c3in9yu4
# PABPiYwTCFG7/N9qS3zcD6+vVkispyVEj2MjPlyXIUZ8TG/0ZiAERsYkKLdY2REC
# m8udOxoxggQhMIIEHQIBATBgMEwxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwx0aGF3
# dGUsIEluYy4xJjAkBgNVBAMTHXRoYXd0ZSBTSEEyNTYgQ29kZSBTaWduaW5nIENB
# AhBoVn/LawJ5wxxFJ25Qn8+LMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPjmGVxSwE9n
# Lau1l39ajhAzEzYGd9taHk5jFG1IyxJlMA0GCSqGSIb3DQEBAQUABIIBAHzs4PiE
# 6Cx4qgUeCZQYTfD45alyycdwEURGC0WAsIfGVCjcnjhaolGe+MUiYaWKiddgt7Me
# K1uj2thbdDbay0ntIEz6N410sE+qbXiSLlr7hChkN5YW7YmnrQLFg5uniAyp9XMA
# lHhL1C+lYXmfuvXzE/g3Mnd7X5djJuyEIGVtzomicRUfPYN2xv9yFfYJmpZTgy2k
# tU9gLTIE2FPZIjO/KUT41OxT890pGBnt9OtLZ94LedbQOz/Rxhc5VKO3RX451WDK
# a2izpSO2C4ypBb+UIWKQmi30gIrnwLuNncRc9IgG4sq6jz0NsJLw3EH4YgGn6hqT
# WoGMwElE1SghJzShggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTkxMDE4MDUxNTMzWjAjBgkqhkiG9w0BCQQx
# FgQUqMPp13eO/+7nAh+A5V25sp0sRfowDQYJKoZIhvcNAQEBBQAEggEAnk1A3ieT
# xqCkYvSTtUKATZV4PGOxyI+q8xheq6dYVHZ0QPOve+0ZZcZX3YuZcgBTWyoRvCYy
# TcxN0jKeuLP+YCdY4md9XEAf7Y1o01SqHCLv+KKvQD84Jy2N1maabFBgfHKcgjAY
# i7GGbbrE8YkE8qXO8KKB7lr7AqPIdM6LkcIpu1rzCiJOyaIizMhoQK9Lovfjou7J
# OaEnkEt0CE1Jv17TbjzcxTV0RgdX2Ae3Q1C7AxiI4LvEv76hIX+8iHObY+L8detK
# 374JvkcownYzA/fwC6jsvALSTt5Pm47itdIjvC7Fc+OxbBt01XwK7NrZ5ebEqg7k
# Kewv1E1/11tA2g==
# SIG # End signature block
