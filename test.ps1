param (
    [switch]$ExitOnRCFailure = $false,
    [switch]$IncludePreprocessorQuirkFiles = $false,
    [switch]$IncludeWin32WillCompileErrorFiles = $false,
    [switch]$ExcludeZigRC = $false,
    [switch]$ErrorOnAnyDiscrepancies = $false,
    [switch]$ErrorOnAnyLikelyPanics = $false,
    [switch]$MinGWCompat = $false
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
$zig_command = "zig"

Ensure-HasCommand "$zig_command"
$compilers[$zig_command] = @{ cmd = $zig_command; successes = 0; expected_errors = 0; unexpected_errors = 0; missing_errors = 0; different_outputs = 0; likely_panics = 0; }

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
    if ($MinGWCompat) {
        # Necessary to avoid a compile error in MinGW's vadefs.h which expects either
        # _MSC_VER or __GNUC__ to be defined. Additionally, one of _M_IA64, _M_IX86,
        # or _M_AMD64 must be defined if _MSC_VER is defined.
        $extra_rc_args += " /D_MSC_VER /D_M_AMD64"
        # Avoid an error in winnt.h
        $extra_rc_args += " /D__x86_64__"
    }
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

    if ($exitcode -eq 0) {
        $empty_zig_path = Join-Path $PSScriptRoot "empty.zig"
        $intermediatedllname = $f.BaseName + ".dll"
        $outdllname = $f.BaseName + ".expected.dll"
        $fulldllname = "$dirname\$outdllname"
        $dllcommand = "$zig_command build-lib -dynamic -OReleaseSmall `"$empty_zig_path`" `"$outfilename`" -femit-bin=`"$intermediatedllname`" 2>&1"

        Write-Log ("Dll Command: $dllcommand")

        Push-Location "$dirname"
        $dlloutput = & cmd /S /C "$dllcommand"
        $dllexitcode = $LASTEXITCODE
        Pop-Location

        if ($dllexitcode -ne 0) {
            Write-Output $f.FullName
            Write-Output $dllexitcode
            Write-Output $dlloutput
            Exit 1
        }

        Push-Location "$dirname"
        Rename-Item -Path "$intermediatedllname" "$outdllname"
        Pop-Location
    }

    $actual_basename = $f.BaseName + "." + $zig_command
    $actual_outfilename = $actual_basename + ".dll"
    $actual_fulloutfile = "$dirname\$actual_outfilename"

    $actual_command_string = "$zig_command build-lib -dynamic -OReleaseSmall `"$empty_zig_path`" -rcflags $extra_rc_args -- `"$rcfilename`" -femit-bin=`"$intermediatedllname`" 2>&1"

    Write-Log ("Command: $actual_command_string")

    Push-Location "$dirname"
    $actual_output = & cmd /S /C "$actual_command_string"
    $actual_exitcode = $LASTEXITCODE
    if (Test-Path -Path "$intermediatedllname") {
        Rename-Item -Path "$intermediatedllname" "$actual_outfilename"
    }
    Pop-Location

    Write-Log ("Command output (exit code: " + $actual_exitcode + "):`n---")
    Write-Log ($actual_output -join "`n")
    Write-Log "---"

    if ($actual_exitcode -ne 0 -and $actual_exitcode -ne 1) {
        Write-Log "LIKELY PANIC: Non-zero and non-one exit code"
        $compilers[$zig_command].likely_panics++
    }

    if ($exitcode -ne 0 -and $actual_exitcode -ne 0) {
        $compilers[$zig_command].expected_errors++
    } elseif ($actual_exitcode -ne 0 -and $exitcode -eq 0) {
        $compilers[$zig_command].unexpected_errors++
        Write-Log "DISCREPANCY: Expected success, but got compile error"
    } elseif ($exitcode -ne 0 -and $actual_exitcode -eq 0) {
        $compilers[$zig_command].missing_errors++
        Write-Log "DISCREPANCY: Expected error, but didn't get one"
    } else {
        $null = & ".\compare-rsrc.exe" "$fulldllname" "$actual_fulloutfile" 2>&1
        $compare_exitcode = $LASTEXITCODE

        if ($compare_exitcode -ne 0) {
            $compilers[$zig_command].different_outputs++
            Write-Log "DISCREPANCY: Different .rsrc outputs"
        } else {
            $compilers[$zig_command].successes++
        }
    }

    Write-Log "`n"

    # clean up
    Remove-Item -Path "$dirname\*.dll"
    Remove-Item -Path "$dirname\*.pdb"
    Remove-Item -Path "$dirname\*.obj"
    Remove-Item -Path "$dirname\*.lib"
    Remove-Item -Path "$dirname\*.res"

    $num_processed++;
    Write-Host -NoNewline "`rProcessed $num_processed .rc files"

    Write-Log "=================================================`n`n"
}

$any_discrepancies = $false
$any_likely_panics = $false
Write-Output ""

Write-Output "`n---------------------------"
Write-Output "  $zig_command"
Write-Output "---------------------------"
$results = $compilers[$zig_command]
if ($results.likely_panics -ne 0) {
    Write-Output "`ncheck $result_log_file for lines with LIKELY PANIC:"
    Write-Output "likely crashes/panics:      $($results.likely_panics)"
    $any_likely_panics = $true
}
$total_discrepancies = $results.unexpected_errors + $results.missing_errors + $results.different_outputs
if ($total_discrepancies -ne 0) {
    Write-Output "`n$total_discrepancies .rc files processed with discrepancies"
    Write-Output "different .rsrc outputs:    $($results.different_outputs)"
    Write-Output "unexpected compile errors:  $($results.unexpected_errors)"
    Write-Output "missing compile errors:     $($results.missing_errors)"
    $any_discrepancies = $true
}
$total_conforming = $results.successes + $results.expected_errors
Write-Output "`n$total_conforming .rc files processed without discrepancies"
Write-Output "identical .rsrc outputs:    $($results.successes)"
Write-Output "expected compile errors:    $($results.expected_errors)"

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
