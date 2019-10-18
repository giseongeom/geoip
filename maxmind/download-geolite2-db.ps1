    $local_path = "$PSSCRIPTROOT"
    if (-not(Test-Path $local_path)) {
        mkdir -ErrorAction SilentlyContinue $local_path -Force | Out-Null
        # Debug
        $local_path
    }

    $tgz_format_list = @"
https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz
https://geolite.maxmind.com/download/geoip/database/GeoLite2-ASN.tar.gz
"@ -split "`n" -notmatch '^#.*' | ForEach-Object { $_.trim() }

    $zip_format_list = @"
https://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip
https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country-CSV.zip
https://geolite.maxmind.com/download/geoip/database/GeoLite2-ASN-CSV.zip
"@ -split "`n" -notmatch '^#.*' | ForEach-Object { $_.trim() }

    $unpack_root = "$(Get-Random)-maxmind-geoip2"
    $unpack_path = $PSSCRIPTROOT + '/' + $unpack_root

    if (!(Test-Path $unpack_path)) {
        mkdir -ErrorAction SilentlyContinue $unpack_path -Force | Out-Null
        # Debug
        $unpack_path
    }
    Push-Location -Path $unpack_path

    $tgz_format_list | ForEach-Object {
        $url = $_
        $tgz_base_filename = 'geoip.tgz'

        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -UseBasicParsing -OutFile $tgz_base_filename -Uri $url -ErrorAction SilentlyContinue
        if (Test-Path $tgz_base_filename) {
            & tar.exe -zxf $tgz_base_filename
            $tgz_extracted_dir = Get-ChildItem -Directory | Select-Object -ExpandProperty FullName

            if (Test-Path $tgz_extracted_dir) {
                $mmdb_files = Get-ChildItem -Recurse -File -Include *.mmdb
                $mmdb_files | ForEach-Object {
                    $mmdb_file = $_.FullName
                    Get-ChildItem $mmdb_file
                    Copy-Item -Path $mmdb_file -Destination $local_path -ErrorAction SilentlyContinue -Force
                }
                Remove-Item $tgz_extracted_dir -Recurse -ErrorAction SilentlyContinue -Force | Out-Null
            }
            Remove-Item $tgz_base_filename -ErrorAction SilentlyContinue -Force | Out-Null
        }
    }

    $zip_format_list | ForEach-Object {
        $url = $_
        $zip_base_filename = 'geoip.zip'

        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -UseBasicParsing -OutFile $zip_base_filename -Uri $url -ErrorAction SilentlyContinue

        if (Test-Path $zip_base_filename) {
            # disable progressbar of Expand-Archive cmdlet
            # $Global:ProgressPreference = 'SilentlyContinue'
            Expand-Archive -Path $zip_base_filename -ErrorAction SilentlyContinue -Force
            $zip_extracted_dir = Get-ChildItem -Directory | Select-Object -ExpandProperty FullName

            if (Test-Path $zip_extracted_dir) {
                $csv_files = Get-ChildItem -Recurse -File -Include *.csv
                $csv_files | ForEach-Object {
                    $csv_file = $_.FullName
                    Get-ChildItem $csv_file
                    Copy-Item -Path $csv_file -Destination $local_path -ErrorAction SilentlyContinue -Force
                }
                Remove-Item $zip_extracted_dir -Recurse -ErrorAction SilentlyContinue -Force | Out-Null
            }
            Remove-Item $zip_base_filename -ErrorAction SilentlyContinue -Force | Out-Null
        }
    }

    # cleanup
    Pop-Location
    # Restore default
    # $Global:ProgressPreference = 'Continue'

    if (Test-Path $unpack_path) {
        Remove-Item -ErrorAction SilentlyContinue $unpack_path -Recurse -Force | Out-Null
    }
