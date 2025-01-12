# Define the output CSV file
$outputCsv = "output.csv"

# Clear the output file if it already exists
if (Test-Path $outputCsv) {
    Remove-Item $outputCsv
}

# Create a synchronized hashtable for thread-safe communication
$syncHash = [hashtable]::Synchronized(@{
    Queue = @()  # Shared queue
    Stop = $false # Signal to stop processing
})

# URL to fetch text from
$textApiUrl = "https://baconipsum.com/api/?type=meat-and-filler&sentences=1"

# First thread: Text Generator (fetches from HTTP request)
$generatorJob = Start-Job -ScriptBlock {
    param ($syncHash, $url)
    for ($i = 1; $i -le 10; $i++) {
        Write-Host "loopdieloop"
        # Fetch text from the HTTP API
        try {
            $response = Invoke-RestMethod -Uri $url -Method Get
            if ($response) {
                $text = $response -join " "  # Join array into a single string if needed
                $syncHash.Queue += @{ ID = $i; Text = $text }
            }
        } catch {
            $syncHash.Queue += @{ ID = $i; Text = "Failed to fetch text" }
        }

        # Simulate processing delay
        Start-Sleep -Milliseconds 500
    }

    # Signal the second thread to stop after generating all text
    $syncHash.Stop = $true
} -ArgumentList $syncHash, $textApiUrl

# Second thread: CSV Appender
$appenderJob = Start-Job -ScriptBlock {
    param ($syncHash, $outputCsv)
    
    # Initialize CSV with headers
    "ID,Text" | Out-File -FilePath $outputCsv -Encoding UTF8

    while (-not $syncHash.Stop -or $syncHash.Queue.Count -gt 0) {
        Write-Host "loop"
        if ($syncHash.Queue.Count -gt 0) {
            # Take the first item from the queue
            $item = $syncHash.Queue[0]
            $syncHash.Queue = $syncHash.Queue[1..($syncHash.Queue.Count - 1)]

            # Append the text to the CSV file
            "$($item.ID),`"$($item.Text.Replace('"', '""'))`"" | Out-File -FilePath $outputCsv -Append -Encoding UTF8
        } else {
            # No items in the queue, wait a short time
            Start-Sleep -Milliseconds 100
        }
    }
} -ArgumentList $syncHash, $outputCsv

# Wait for both jobs to complete
Wait-Job -Job $generatorJob
Wait-Job -Job $appenderJob

# Clean up jobs
Remove-Job -Job $generatorJob
Remove-Job -Job $appenderJob

# Output the results
Write-Output "Contents of the CSV file '$outputCsv':"
Get-Content -Path $outputCsv