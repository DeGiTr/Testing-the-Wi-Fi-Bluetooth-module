$ErrorActionPreference = 'SilentlyContinue'

function Test-WifiOk {
    $keywords = @('Wi-Fi', 'WiFi', 'Wireless', 'WLAN', '802.11', 'Беспровод')
    $pattern = ($keywords | ForEach-Object { [Regex]::Escape($_) }) -join '|'

    $cmd = Get-Command Get-NetAdapter -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $adapters = Get-NetAdapter -Physical -ErrorAction Stop
        } catch {
            $adapters = $null
        }

        if ($null -ne $adapters) {
            foreach ($adapter in $adapters) {
                $isWifi = $false
                if ($null -ne $adapter.NdisPhysicalMedium -and $adapter.NdisPhysicalMedium -eq 9) {
                    $isWifi = $true
                } else {
                    $text = ($adapter.InterfaceDescription + ' ' + $adapter.Name)
                    if ($text -match $pattern) {
                        $isWifi = $true
                    }
                }

                if ($isWifi -and $adapter.AdminStatus -eq 'Up') {
                    return $true
                }
            }
            return $false
        }
    }

    $cimAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction SilentlyContinue
    foreach ($adapter in $cimAdapters) {
        $text = ($adapter.Name + ' ' + $adapter.NetConnectionID + ' ' + $adapter.Description)
        if ($text -match $pattern -and $adapter.NetEnabled -eq $true) {
            return $true
        }
    }

    return $false
}

function Test-BluetoothOk {
    $cmd = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $devices = Get-PnpDevice -Class Bluetooth -PresentOnly -ErrorAction Stop
        } catch {
            $devices = $null
        }

        if ($null -ne $devices) {
            foreach ($device in $devices) {
                $name = $device.FriendlyName
                if (-not $name) {
                    $name = $device.Name
                }
                $instanceId = $device.InstanceId

                if ($instanceId -match '^BTHENUM\\') {
                    continue
                }
                if ($name -match 'Enumerator') {
                    continue
                }

                if ($device.Status -eq 'OK' -and ($null -eq $device.Problem -or $device.Problem -eq 0)) {
                    return $true
                }
            }
            return $false
        }
    }

    $cimDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue
    foreach ($device in $cimDevices) {
        if ($device.Name -notmatch 'Bluetooth') {
            continue
        }
        if ($device.Name -match 'Enumerator') {
            continue
        }
        if ($device.PNPDeviceID -match '^BTHENUM\\') {
            continue
        }
        if ($device.ConfigManagerErrorCode -eq 0) {
            return $true
        }
    }

    return $false
}

Write-Host 'Добро пожаловать в программу тестирования Wi-Fi адаптер M.2 v2 (БСГФ.467144.001). Выполняется тестирование:'

$wifiOk = Test-WifiOk
$btOk = Test-BluetoothOk

if ($wifiOk -and $btOk) {
    Write-Host 'Тестирование успешно!' -ForegroundColor Green
    exit 0
} else {
    Write-Host 'Тестирование неуспешно' -ForegroundColor Red
    exit 1
}
