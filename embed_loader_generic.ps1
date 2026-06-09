param(
    [Parameter(Mandatory=$true)][string]$Table,     # e.g. dbo.CustomerProfileVectors
    [Parameter(Mandatory=$true)][string]$KeyCol,     # e.g. BusinessEntityID
    [Parameter(Mandatory=$true)][string]$TextCol,    # e.g. ProfileText
    [Parameter(Mandatory=$true)][string]$VecCol,     # e.g. Embedding
    [string]$Prefix = 'search_document: ',
    [int]$Dim = 768,
    [int]$Batch = 32,
    [string]$Database = 'AdventureWorks2025',
    [int]$MaxChars = 0
)
$ErrorActionPreference = 'Stop'
$connStr = "Server=localhost;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Encrypt=False"
$ollama  = 'http://localhost:11434/api/embed'
$model   = 'nomic-embed-text'
$inv     = [System.Globalization.CultureInfo]::InvariantCulture
Add-Type -AssemblyName System.Data

$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
$conn.Open()
$rows = New-Object System.Collections.ArrayList
$read = $conn.CreateCommand()
$read.CommandText = "SELECT $KeyCol, $TextCol FROM $Table WHERE $VecCol IS NULL AND $TextCol IS NOT NULL AND LEN(CAST($TextCol AS nvarchar(max))) > 0 ORDER BY $KeyCol"
$read.CommandTimeout = 120
$rdr = $read.ExecuteReader()
while ($rdr.Read()) { [void]$rows.Add([pscustomobject]@{ Id = $rdr.GetValue(0); Text = [string]$rdr.GetValue(1) }) }
$rdr.Close()
Write-Host ("[{0}] rows to embed: {1}" -f $Table, $rows.Count)
if ($rows.Count -eq 0) { $conn.Close(); Write-Host 'Nothing to do.'; return }

function Get-Embeddings([string[]]$texts) {
    # Build JSON by hand (PS 5.1 ConvertTo-Json mangles some real-world text). Control chars
    # are already stripped by the caller; here we escape backslash and double-quote, then send UTF-8 bytes.
    $esc = $texts | ForEach-Object { '"' + ($_.Replace('\','\\').Replace('"','\"')) + '"' }
    $payload = '{"model":"' + $model + '","input":[' + ($esc -join ',') + ']}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $resp = Invoke-RestMethod -Uri $ollama -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 300
    return ,$resp.embeddings
}

$done = 0; $sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt $rows.Count; $i += $Batch) {
    $slice = $rows[$i..([math]::Min($i + $Batch - 1, $rows.Count - 1))]
    # clean: strip HTML tags + decode common entities, then strip control chars (JSON-safe)
    $texts = $slice | ForEach-Object {
        $t = [string]$_.Text -replace '<[^>]+>', ' '
        $t = $t -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&#39;', "'" -replace '&quot;', '"'
        $clean = ($Prefix + $t) -replace '[\x00-\x1F\x7F]', ' '
        if ($MaxChars -gt 0 -and $clean.Length -gt $MaxChars) { $clean = $clean.Substring(0, $MaxChars) }
        $clean
    }
    try {
        $embs  = Get-Embeddings $texts
        for ($j = 0; $j -lt $slice.Count; $j++) {
            $lit = '[' + (($embs[$j] | ForEach-Object { ([double]$_).ToString('R', $inv) }) -join ',') + ']'
            $upd = $conn.CreateCommand()
            $upd.CommandText = "UPDATE $Table SET $VecCol = CAST(@v AS VECTOR($Dim)) WHERE $KeyCol = @id"
            [void]$upd.Parameters.Add('@v',  [System.Data.SqlDbType]::NVarChar, -1)
            [void]$upd.Parameters.Add('@id', [System.Data.SqlDbType]::Int)
            $upd.Parameters['@v'].Value  = $lit
            $upd.Parameters['@id'].Value = [int]$slice[$j].Id
            [void]$upd.ExecuteNonQuery()
            $done++
        }
    } catch {
        Write-Host ("  batch @" + $i + " failed, skipping: " + $_.Exception.Message)
    }
    if (($done % 512) -lt $Batch) {
        $rate = [math]::Round($done / $sw.Elapsed.TotalSeconds, 1)
        Write-Host ("  {0}/{1}  ({2}/s)" -f $done, $rows.Count, $rate)
    }
}
$conn.Close()
Write-Host ("DONE {0} rows in {1}s" -f $done, [math]::Round($sw.Elapsed.TotalSeconds,1))
