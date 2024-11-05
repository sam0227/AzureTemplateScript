$scriptContent = @'
$baseUrl = "http://localhost:80/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($baseUrl)

$sqlService = Get-Service -Name 'MSSQLSERVER' -ErrorAction SilentlyContinue

$listener.Start()
Write-Host "Listening on http://localhost:80/"

function Get-Health {
    param (
        $context
    )

    $response = $context.Response
    if ($null -ne $sqlService -and $sqlService.Status -eq 'Running') {
        $response.StatusCode = 200
        $responseBody = '{"ApplicationHealthState": "Healthy"}'
    } else {
        $response.StatusCode = 400
        $responseBody = '{\"error\": \"SQL Server is not running\"}'
    }
    
    $response.ContentType = "application/json"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)

    $response.Close()

    Write-Host "Responded with $($response.StatusCode) for GET /health"
}

function Handle-Request {
    param (
        $context
    )

    $request = $context.Request

    switch ($request.HttpMethod) {
        'GET' {
            switch ($request.Url.AbsolutePath) {
                '/healthEndpoint' {
                    Get-Health -context $context
                }
                default {
                    Write-Host "Received unknown GET request"
                    $response = $context.Response
                    $response.StatusCode = 404
                    $response.Close()
                }
            }
        }
        default {
            Write-Host "Received unknown HTTP method"
            $response = $context.Response
            $response.StatusCode = 405
            $response.Close()
        }
    }
}

while ($true) {
    $context = $listener.GetContext()
    Handle-Request -context $context
}
'@

# Save the script content to a file
$tempFilePath = "SQLServerHealthChecker.ps1"
$scriptContent | Out-File -FilePath $tempFilePath -Encoding UTF8


# Start the script in a new PowerShell window
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -File `"$tempFilePath`"" -WindowStyle Normal

# Exit the current script after starting the new one
Write-Host "Script started in a new window and running in the background. Exiting current script."