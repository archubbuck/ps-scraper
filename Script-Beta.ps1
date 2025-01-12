# Define the output file
$outputFile = "output.txt"

# Clear the output file if it already exists
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Create a synchronized hashtable for thread-safe communication
$syncHash = [hashtable]::Synchronized(@{
    Queue = @()  # Shared queue
    Stop = $false # Signal to stop processing be
})

# URL to fetch text from
$textApiUrl = "https://baconipsum.com/api/?type=meat-and-filler&sentences=1"

# First thread: Text Generator (fetches from HTTP request)
$generatorJob = Start-Job -ScriptBlock {
    param ($syncHash, $url)
    for ($i = 1; $i -le 10; $i++) {
        # Fetch text from the HTTP API
        try {
            $response = Invoke-RestMethod -Uri $url -Method Get
            if ($response) {
                $text = $response -join " "  # Join array into a single string if needed
                $syncHash.Queue += "[$i] $text"
            }
        } catch {
            $syncHash.Queue += "[$i] Failed to fetch text"
        }

        # Simulate processing delay
        Start-Sleep -Milliseconds 500
    }

    # Signal the second thread to stop after generating all text
    $syncHash.Stop = $true
} -ArgumentList $syncHash, $textApiUrl

# Second thread: Text Appender
$appenderJob = Start-Job -ScriptBlock {
    param ($syncHash, $outputFile)
    while (-not $syncHash.Stop -or $syncHash.Queue.Count -gt 0) {
        if ($syncHash.Queue.Count -gt 0) {
            # Take the first item from the queue
            $text = $syncHash.Queue[0]
            $syncHash.Queue = $syncHash.Queue[1..($syncHash.Queue.Count - 1)]

            # Append the text to the output file
            Add-Content -Path $outputFile -Value $text
        } else {
            # No items in the queue, wait a short time
            Start-Sleep -Milliseconds 100
        }
    }
} -ArgumentList $syncHash, $outputFile

# Wait for both jobs to complete
Wait-Job -Job $generatorJob
Wait-Job -Job $appenderJob

# Clean up jobs
Remove-Job -Job $generatorJob
Remove-Job -Job $appenderJob

# Output the results
Write-Output "Contents of the file '$outputFile':"
Get-Content -Path $outputFile