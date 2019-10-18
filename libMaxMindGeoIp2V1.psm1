<#
Windows PowerShell library for performing geo IP lookups.

Requirements:
- Windows PowerShell 5.1.16299.98
  $PSVersionTable.PSVersion

- .NET Framework 4.5
  https://www.microsoft.com/net/download/dotnet-framework-runtime

- nuget
  https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

- MaxMind.DB nuget package
  nuget install MaxMind.Db

- GeoLite2 MaxMind DB binary
  https://dev.maxmind.com/geoip/geoip2/geolite2
#>

New-Module -Name libMaxMindGeoIp2V1 -ScriptBlock {
    function New-GeoIp2Reader
    {
        param (
            $Library,
            $Database
        )

        Add-Type -Path $Library | Out-Null

        return [MaxMind.Db.Reader]::new($Database)
    }

    function Close-GeoIp2Reader
    {
        param (
            [ref]$Reader
        )

        $Reader.Value.Dispose()
        $Reader.Value = $null
    }

    function Find-GeoIp2
    {
        param (
            $Reader,
            $IpAddress,
            $Library,
            $Database
        )

        $results = $null
        $readerInternal = $Reader -eq $null -and $Library -ne $null -and $Database -ne $null

        $ip = [System.Net.IPAddress]$IpAddress

        if ($readerInternal)
        {
            $Reader = New-GeoIp2Reader -Library $Library -Database $Database
        }

        if ($Reader)
        {
            # Use the first Find method and tell it to return type Dictionary<string, object>.
            $oldMethod = ($Reader.GetType().GetMethods() |? {$_.Name -eq 'Find'})[0]
            $newMethod = $oldMethod.MakeGenericMethod(@([System.Collections.Generic.Dictionary`2[System.String,System.Object]]))

            # Call our new method, T Find[T](ipaddress ipAddress, MaxMind.Db.InjectableValues injectables)
            $results = $newMethod.Invoke($Reader, @($ip, $null))

            if ($readerInternal)
            {
                Close-GeoIp2Reader -Reader ([ref]$Reader)
            }
        }
        else
        {
            throw 'MaxMind.Db.Reader not defined.'
        }

        return $results
    }

    Export-ModuleMember -Function 'New-GeoIp2Reader', 'Find-GeoIp2', 'Close-GeoIp2Reader'
}