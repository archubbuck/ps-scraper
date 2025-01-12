$url = "https://baconipsum.com/api/?type=meat-and-filler&sentences=1"

$response = Invoke-RestMethod -Uri $url -Method Get

$text = $response -join " "

$outputFile = "output.txt"

Add-Content -Path $outputFile -Value $text