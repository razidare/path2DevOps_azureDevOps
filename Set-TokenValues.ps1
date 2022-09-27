<# 
.SYNOPSIS
    Replaces the environment variables trapped between tokens with their values
.EXAMPLE
    Convert-TokensToVariables -inputFilePath "C:\Users\Shikki\demo.txt"
#>

param (
    [parameter(Mandatory=$false)][string]$startToken = "#{",    #delimiter to the left of the variable
    [parameter(Mandatory=$false)][string]$endToken   = "}#",    #delimiter to the right of the variable
    [parameter(Mandatory=$true)][string]$inputFilePath   #pathToFile
)

#get the file content and initialize utils
$content            = Get-Content $inputFilePath -Encoding UTF8 -ea stop
$modifiedContent    = $content
$regex              = "$startToken[a-zA-Z0-9_-]*$endToken"

Write-Host "Working with file $inputFilePath"

#get a list of all variables to be replaced
$listOfTokenizedVariables = ([regex]::Matches($content, $regex)).value
Write-Host -ForegroundColor Cyan "List of Tokens: $($listOfTokenizedVariables -join ", ")"

foreach ($object in $listOfTokenizedVariables) {
    $temporary = $object.replace($startToken,'').replace($endToken,'')
    #check for ENV var with $temporary name

    #if variable does not exist what do? -> throw exception
    if ([string]::IsNullOrEmpty([System.Environment]::GetEnvironmentVariable($temporary))) {
        #variable is not initialized
        Write-Error "Token $object does not have a corresponding variable" -ErrorAction Stop #remove tokens that don't have a corresponding ENV var
    } else {
        #replace tokenized variabile name with variable value
        Write-Host -ForegroundColor Blue "Replacing token: $object with environment variable: $temporary"
        $modifiedContent = $modifiedContent -replace $object, [System.Environment]::GetEnvironmentVariable($temporary) #[regex]::Replace($modifiedContent, $object, ([System.Environment]::GetEnvironmentVariable($temporary))) - this breaks the multiline string and returns a single line
    }
}

Out-File -FilePath $inputFilePath -Encoding UTF8 -InputObject $modifiedContent