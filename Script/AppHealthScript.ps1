# Define the PowerShell script content to be run in a new window
$scriptContent = @'
# Define the URL to listen on
$baseUrl = "http://localhost:80/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($baseUrl)

# Check if SQL Server is running
$sqlService = Get-Service -Name 'MSSQLSERVER' -ErrorAction SilentlyContinue

$listener.Start()
Write-Host "Listening on http://localhost:80/"

# Method to handle GET /health requests
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
        $responseBody = "{\"error\": \"SQL Server is not running\"}"
    }
    
    $response.ContentType = "application/json"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)

    # Close the response
    $response.Close()

    Write-Host "Responded with $($response.StatusCode) for GET /health"
}

# Function to route requests to the appropriate handler
function Handle-Request {
    param (
        $context
    )

    $request = $context.Request

    switch ($request.HttpMethod) {
        'GET' {
            switch ($request.Url.AbsolutePath) {
                '/health' {
                    Get-Health -context $context
                }
                default {
                    # Handle unknown GET requests
                    Write-Host "Received unknown GET request"
                    $response = $context.Response
                    $response.StatusCode = 404
                    $response.Close()
                }
            }
        }
        default {
            # Handle unknown HTTP methods
            Write-Host "Received unknown HTTP method"
            $response = $context.Response
            $response.StatusCode = 405
            $response.Close()
        }
    }
}

# Infinite loop to keep the server running
while ($true) {
    # Wait for an incoming request
    $context = $listener.GetContext()
    Handle-Request -context $context
}
'@

# Save the script content to a temporary file
$tempFilePath = [System.IO.Path]::GetTempFileName() + ".ps1"
$scriptContent | Out-File -FilePath $tempFilePath -Encoding UTF8

# Start the script in a new PowerShell window
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -File `"$tempFilePath`"" -WindowStyle Hidden

# Exit the current script after starting the new one
Write-Host "Script started in a new window and running in the background. Exiting current script."
