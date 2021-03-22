#!/usr/bin/env pwsh
<#

Copyright (c) 2021 Sebastiaan Dammann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. 

#>

using namespace System.IO

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    $SourceFile
)

if (!$SourceFile) {
    Write-Error "No source file provided on the command line"
    Exit -1
}

if (!$(Test-Path $SourceFile)) {
    Write-Error "Source file '$SourceFile' does not exist"
    Exit -1
}

Write-Host "Processing $SourceFile" -ForegroundColor Green

# Defs
class GObject {
    [int] $Id;
    [int] $Copy;
    [int] $Index;
}

[GObject[]] $Objects = @()

function Find-Object {
    [OutputType([GObject])]
    Param ([int] $Id, [int] $Copy)

    foreach ($Obj in $Script:Objects) {
        if ($Obj.Id -eq $Id -and $Obj.Copy -eq $Copy) {
            Return $Obj
        }
    }

    # Create new object
    $Obj = [GObject]::new()
    $Obj.Id = $Id
    $Obj.Copy = $Copy
    $Obj.Index = $Objects.Length

    $Script:Objects += @($Obj)

    Return $Obj
}

function Get-CurrentIndex() {
    Return $Script:Objects.Length
}

# We match on this
$StartRegex = "; printing object (?<NAME>.*) id:(?<ID>\d+) copy (?<COPY>\d+)"
$EndRegex = "; stop printing object (?<NAME>.*) id:(?<ID>\d+) copy (?<COPY>\d+)"

# Open file
$TmpFile = [Path]::GetTempFileName()

Write-Host "Opening $TmpFile and $SourceFile" -ForegroundColor Gray

[StreamReader] $Reader;
[StreamWriter] $Writer;

try {
    $Reader = [StreamReader]::new($SourceFile);
    $Writer = [StreamWriter]::new($TmpFile);
} catch {
    Write-Error -Message "Unable to open read/write streams to $SourceFile and $TmpFile"  -Exception $_.Exception
    Start-Sleep -Seconds 1
    Exit -1
}

# Handle each line
$LineIndex = 0
$Line = $Reader.ReadLine()

$Writer.WriteLine("                              ; Processed by Add-CancelObjects.ps1 script")

while ($null -ne $Line) {
    # Copy line
    $Writer.WriteLine($Line)

    # Match delimiters
    if ($Line -imatch $StartRegex) {
        $Id = [int] $MATCHES["ID"]
        $Copy = [int] $MATCHES["COPY"]

        Write-Host "Line $($LineIndex + 1): Found object $Id (copy $Copy)" -ForegroundColor Cyan
        $Obj = Find-Object -Id $Id -Copy $Copy

        $Writer.WriteLine("M486 S$($Obj.Index)   ; Add-Objects.ps1")
    } else {
        if ($Line -imatch $EndRegex) {
            Write-Host "`tLine $($LineIndex + 1): end of object $Id (copy $Copy)" -ForegroundColor Cyan
            $Writer.WriteLine("M486 S-1   ; Add-Objects.ps1")
        }
    }

    # Next line
    $LineIndex++
    $Line = $Reader.ReadLine()
}

$Reader.Close()

if ($Objects.Length -eq 0) {
    Write-Error "Didn't find any objects to process. Error!"
    Start-Sleep -Seconds 1
    Exit -1
}

# Insert total number of objects
Write-Host "Total number of objects processed: $($Objects.Length)" -ForegroundColor Green
Write-Host "Writing header..." -ForegroundColor Gray

# Do some flush trickery to write the first line
$Writer.Flush()
$Writer.BaseStream.Position = 0
$Writer.Write("M486 T$($Objects.Length)")
$Writer.Close()

Write-Host "Overwriting file..." -ForegroundColor Gray
try {
    Copy-Item -Path $TmpFile -Destination $SourceFile -Force
} catch {
    Write-Error -Message "Unable to copy $TmpFile to $SourceFile"  -Exception $_.Exception
    Start-Sleep -Seconds 1
    Exit -1
}

Write-Host "Done! Happy printing!" -ForegroundColor Green
