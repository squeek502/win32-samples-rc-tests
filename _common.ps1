function Test-HasCommand {
    param ( $cmd )

    if (Get-Command $cmd -ErrorAction SilentlyContinue)
    {
        return 1
    }
    return 0
}

function Ensure-HasCommand {
    param ( $cmd )

    if (Test-HasCommand $cmd) { return }

    # Need vcvars32 for uicc.exe and gc.exe, and I think the 32-bit versions
    # are fine for everything, so just recommend that unconditionally
    Write-Error "'$cmd' not found, ensure that you are running this script from one of the following:`n - 'Developer PowerShell for VS'`n - 'x86 Native Tools Command Prompt for VS'`n - An environment in which 'vcvars32.bat' has been executed"
    exit 1
}


function Test-IsUtf16Le {
    param ( $path )

    [byte[]]$bytes = Get-Content -Encoding byte -ReadCount 2 -TotalCount 2 -Path "$path"
    if ($null -eq $bytes) { return $false }

    # FF FE (UTF-16 Little-Endian)
    return $bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe
}

# Returns 1 for .rc files that are known to rely on a Win32 RC preprocessor quirk,
# or 0 otherwise.
function Test-Win32PreprocessorQuirk {
    param ( $f )

    # This file uses strings that are split with splices (\ at the end of a line)
    # and the following line has whitespace before the string continues. The Win32
    # RC preprocessor collapses this whitespace when collapsing the splices, but other
    # preprocessors will only collapse the newline when collapsing the splices,
    # so compiling this file will lead to different outcomes purely based on preprocessor
    # behavior.
    if ($f.Name -eq "NonDefaultDropMenuVerb.rc") { return 1 }

    return 0
}

# Returns 1 for .rc files that are known to cause the Win32 RC compiler to
# error, or 0 otherwise.
function Test-Win32WillCompileError {
    param ( $f )

    # This file attempts to reference a "template_MTS.tlb" file that doesn't exist
    # and is not generatable from the files included in the samples (presumably it
    # would come from the template_mts.odl but that also references a missing
    # "ModuleCore.idl")
    if ($f.Name -eq "template_mts.rc") { return 1 }

    # This file attempts to reference two .tlb files that don't exist and aren't
    # generatable. Additionally, this rc isn't even referenced in the vcproj, *and*
    # the vcproj isn't referenced in any .sln.
    if ($f.Name -eq "sampleosp.rc") { return 1 }

    # This file is missing wmsplaylistparser.idl from the SDK, it seems to have
    # been included in a previous SDK version but is no longer present.
    if ($f.Name -eq "SDKSamplePlaylistPlugin.rc") { return 1 }

    # The .rc files in this directory are templates and have strings that are
    # meant for string replacement, so the .rc files aren't intended for direct
    # compilation
    if ($f.FullName -match "Win7Samples\\multimedia\\WMP\\Wizards") { return 1 }

    # This .rc file is not referenced by the .sln and seems to depend on some
    # PEERNETBASEDIR that I have no information about
    if ($f.FullName -match "Win7Samples\\netds\\peertopeer\\DRT\\version.rc") { return 1 }

    # The .rc files here depend on "version.h" that may have been part of a previous SDK
    if ($f.FullName -match "Win7Samples\\sysmgmt\\msi\\(create|process|remove|tutorial).dll") { return 1 }

    # These are files that are only meant to be included from another .rc file
    # (they use definitions that come from header files that they don't themselves include)
    if ($f.FullName -match "dictationpad\\(chs|cht|deu)_dictpad.rc") { return 1 }
    if ($f.FullName -match "speech\\reco\\[a-z]+_reco.rc") { return 1 }

    return 0
}