param (
    [switch]$ExitOnRCFailure = $false,
    [switch]$IncludePreprocessorQuirkFiles = $false,
    [switch]$IncludeWin32WillCompileErrorFiles = $false,
    [switch]$ExcludeWindres = $false,
    [switch]$ExcludeLLVMRC = $false,
    [switch]$ExcludeResinator = $false,
    [switch]$ExcludeZigRC = $false,
    [switch]$ErrorOnAnyDiscrepancies = $false,
    [switch]$ErrorOnAnyLikelyPanics = $false
)

. ".\_common.ps1"

Ensure-HasCommand "rc.exe"

$result_log_file = "results.log"
$null = New-Item "$result_log_file" -ItemType File -Force

function Write-Log {
    param ( $message )
    # for some reason Add-Content was sporadically failing with 'Stream was not readable'
    # so this is used instead
    [System.IO.File]::AppendAllText($result_log_file, "$message`n")
}

$compilers = @{
    rc = @{ cmd = "rc.exe"; successes = 0; errors = 0; }
}
$alt_compilers = @("resinator", "windres", "llvm-rc", "zig")
foreach($alt_compiler in $alt_compilers)
{
    if ($ExcludeResinator -and $alt_compiler -eq "resinator") { continue }
    if ($ExcludeWindres -and $alt_compiler -eq "windres") { continue }
    if ($ExcludeLLVMRC -and $alt_compiler -eq "llvm-rc") { continue }
    if ($ExcludeZigRC -and $alt_compiler -eq "zig") { continue }

    if (Test-HasCommand $alt_compiler) {
        $compilers[$alt_compiler] = @{ cmd = $alt_compiler; successes = 0; expected_errors = 0; unexpected_errors = 0; missing_errors = 0; different_outputs = 0; likely_panics = 0; }
        Write-Output "Found RC compiler: $alt_compiler"

        if ($alt_compiler -eq "windres") {
            # Set up extra windres includes using shortname paths from INCLUDE
            #
            # There are two hacks/workarounds happening here:
            #  1. windres does not search the paths in the INCLUDE environment variable,
            #     so we manually provide each one via the command line
            #  2. windres can't handle spaces in -I include paths at all, so we must
            #     get the 'short name' for all INCLUDE paths (e.g. `C:\Program Files` ->
            #     `C:\PROGRA~1`)
            #
            # This is necessary to allow windres to successfully compile .rc files that
            # include .rc files from the Windows SDK, e.g. `afxres.rc`
            $extra_windres_include_paths = $env:INCLUDE -split ";" | ForEach-Object { (New-Object -ComObject Scripting.FileSystemObject).GetFolder($_).ShortPath }
        }
    }
}

if ($compilers.Count -eq 1 -and -not $ExitOnRCFailure) {
    Write-Error "No alternate RC compilers found in the PATH. To test with only the Win32 RC compiler, -ExitOnRCFailure is required."
    exit 1
}

Write-Output ""

Write-Log "=================================================`n"

$num_processed = 0
$files = Get-ChildItem "Windows-classic-samples\Samples" -Recurse -Include *.rc
foreach($f in $files) {
    if (-not $IncludePreprocessorQuirkFiles -and (Test-Win32PreprocessorQuirk $f)) { continue }
    if (-not $IncludeWin32WillCompileErrorFiles -and (Test-Win32WillCompileError $f)) { continue }

    $dirname = Split-Path $f.FullName
    $outfilename = $f.BaseName + ".expected.res"
    $rcfilename = $f.Name
    $fulloutfile = "$dirname\$outfilename"
    $extra_include_paths = @()
    if ($dirname -match "oledb_conformance") {
        $pos = $dirname.IndexOf("oledb_conformance")
        $include_dir_parent = $dirname.Substring(0, $pos + "oledb_conformance".Length)
        $extra_include_paths += "$include_dir_parent\include"
    }
    if ($dirname -match "Win7Samples\\netds\\eap\\eaphost") {
        $extra_include_paths += "..\inc"
    }
    $extra_rc_args = $extra_include_paths | ForEach-Object {"/I", "`"$_`""}
    $command_string = "rc.exe /fo `"$outfilename`" $extra_rc_args `"$rcfilename`" 2>&1"

    Push-Location "$dirname"
    $output = & cmd /S /C "$command_string"
    $exitcode = $LASTEXITCODE
    Pop-Location

    Write-Log ("Cwd: $dirname")
    Write-Log ("Rc: $rcfilename`n")
    Write-Log ("Command: $command_string")
    Write-Log ("Command output (exit code: " + $exitcode + "):`n---")
    Write-Log ($output -join "`n")
    Write-Log "---`n"

    if ($ExitOnRCFailure -and $exitcode -ne 0) {
        Write-Output $f.FullName
        Write-Output $exitcode
        Write-Output $output
        Exit 1
    } else {
        if ($exitcode -eq 0) {
            $compilers["rc"]["successes"]++;
        } else {
            $compilers["rc"]["errors"]++;
        }
    }

    foreach ($alt_compiler in $alt_compilers) {
        if (-not $compilers[$alt_compiler]) { continue }

        $compiler_cmd = $compilers[$alt_compiler].cmd
        if ($alt_compiler -eq "zig") {
            $compiler_cmd = $compiler_cmd + " rc"
        }
        $actual_outfilename = $f.BaseName + "." + $alt_compiler + ".res"
        $actual_fulloutfile = "$dirname\$actual_outfilename"

        if ($alt_compiler -ne "windres") {
            $actual_command_string = "$compiler_cmd /fo `"$actual_outfilename`" $extra_rc_args `"$rcfilename`" 2>&1"
        } else {
            $all_extra_include_paths = $extra_include_paths + $extra_windres_include_paths
            $extra_windres_args = $all_extra_include_paths | ForEach-Object {"-I", "`"$_`""}
            $actual_command_string = "$compiler_cmd $extra_windres_args `"$rcfilename`" `"$actual_outfilename`" 2>&1"
        }

        Write-Log ("Command: $actual_command_string")

        Push-Location "$dirname"
        $actual_output = & cmd /S /C "$actual_command_string"
        $actual_exitcode = $LASTEXITCODE
        Pop-Location

        Write-Log ("Command output (exit code: " + $actual_exitcode + "):`n---")
        Write-Log ($actual_output -join "`n")
        Write-Log "---"

        if ($actual_exitcode -ne 0 -and $actual_exitcode -ne 1) {
            Write-Log "LIKELY PANIC: Non-zero and non-one exit code"
            $compilers[$alt_compiler].likely_panics++
        }

        if ($exitcode -ne 0 -and $actual_exitcode -ne 0) {
            $compilers[$alt_compiler].expected_errors++
        } elseif ($actual_exitcode -ne 0 -and $exitcode -eq 0) {
            $compilers[$alt_compiler].unexpected_errors++
            Write-Log "DISCREPANCY: Expected success, but got compile error"
        } elseif ($exitcode -ne 0 -and $actual_exitcode -eq 0) {
            $compilers[$alt_compiler].missing_errors++
            Write-Log "DISCREPANCY: Expected error, but didn't get one"
        } else {
            $null = & "fc.exe" /B "$fulloutfile" "$actual_fulloutfile"
            $compare_exitcode = $LASTEXITCODE

            if ($compare_exitcode -ne 0) {
                $compilers[$alt_compiler].different_outputs++
                Write-Log "DISCREPANCY: Different .res outputs"
            } else {
                $compilers[$alt_compiler].successes++
            }
        }

        Write-Log "`n"

        if (Test-Path -Path "$actual_fulloutfile") {
            Remove-Item -Path "$actual_fulloutfile"
        }
    }

    # clean up .res
    if (Test-Path -Path "$fulloutfile") {
        Remove-Item -Path "$fulloutfile"
    }

    $num_processed++;
    Write-Host -NoNewline "`rProcessed $num_processed .rc files"

    Write-Log "=================================================`n`n"
}

$any_discrepancies = $false
$any_likely_panics = $false
Write-Output ""
foreach ($alt_compiler in $alt_compilers) {
    if (-not $compilers[$alt_compiler]) { continue }
    $compiler_name = $alt_compiler
    if ($compiler_name -eq "zig") {
        $compiler_name = "zig rc"
    }
    Write-Output "`n---------------------------"
    Write-Output "  $compiler_name"
    Write-Output "---------------------------"
    $results = $compilers[$alt_compiler]
    if ($results.likely_panics -ne 0) {
        Write-Output "`ncheck $result_log_file for lines with LIKELY PANIC:"
        Write-Output "likely crashes/panics:      $($results.likely_panics)"
        $any_likely_panics = $true
    }
    $total_discrepancies = $results.unexpected_errors + $results.missing_errors + $results.different_outputs
    if ($total_discrepancies -ne 0) {
        Write-Output "`n$total_discrepancies .rc files processed with discrepancies"
        Write-Output "different .res outputs:     $($results.different_outputs)"
        Write-Output "unexpected compile errors:  $($results.unexpected_errors)"
        Write-Output "missing compile errors:     $($results.missing_errors)"
        $any_discrepancies = $true
    }
    $total_conforming = $results.successes + $results.expected_errors
    if ($total_conforming -ne 0) {
        Write-Output "`n$total_conforming .rc files processed without discrepancies"
        if ($results.successes -ne 0) {
            Write-Output "identical .res outputs:     $($results.successes)"
        }
        if ($results.expected_errors -ne 0) {
            Write-Output "expected compile errors:    $($results.expected_errors)"
        }
    }
}

Write-Output "`n---------------------------"
Write-Output "`nSee $result_log_file for details about each file`n"

if ($any_discrepancies -and $ErrorOnAnyDiscrepancies) {
    Write-Error "Found at least one discrepancy"
    exit 1
}
if ($any_likely_panics -and $ErrorOnAnyLikelyPanics) {
    Write-Error "Found at least one likely panic"
    exit 1
}
