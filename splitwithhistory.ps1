param(
    [int][Alias("s")]
    $start,
    [int][Alias("e")]
    $end,
    [string][Alias("p","prefix")]
    $commitPrefix = '',
    [string][Alias("o", "source")]
    $sourceFile,
    [string][Alias("t", "targetExtraction")]
    $targetFileExtraction,
    [string][Alias("tr", "targetRemainder")]
    $targetFileRemainder,
    [string][Alias("b1", "branch1")]
    $temporaryBranchName1 = 'temporaryhistorybranch1',
    [string][Alias("b2", "branch2")]
    $temporaryBranchName2 = 'temporaryhistorybranch2')

# Function to extract line range from a given file into another file
# while preserving git history in both files. Example usage:
# splitwithhistory -s 20 -e 70 -p 'AC-82445' -o 'WebSites\Pure\PX.Objects\AR\Descriptor\Attribute.cs' -t 'WebSites\Pure\PX.Objects\AR\Descriptor\NewAttribute.cs'

if (!$start) { throw New-Object System.ArgumentException "The start line -s is not specified." }
if (!$end) { throw New-Object System.ArgumentException "The end line -e is not specified." }
if (!$commitPrefix) { throw New-Object System.ArgumentException "The commit prefix -p is not specified." }
if (!$sourceFile) { throw New-Object System.ArgumentException "The source file name -o is not specified." }
if (!$targetFileExtraction) { throw New-Object System.ArgumentException "The target file name -t for the extracted part is not specified." }

$remainderDiffers = $true

if (!$targetFileRemainder) 
{
    $remainderDiffers = $false
    $targetFileRemainder = $sourceFile + "temp"
}

if ($start -lt 1) { throw New-Object System.ArgumentOutOfRangeException "The start line should be positive." }
if ($end -lt 1) { throw New-Object System.ArgumentOutOfRangeException "The end line should be positive." }
if ($start -gt $end) { throw New-Object System.ArgumentException ("The start line {0} is greater than the end line {1}" -f $start, $end) }
if (!(Test-Path $sourceFile)) { throw New-Object System.ArgumentException ("Source file '{0}' does not exist." -f $sourceFile) }
if (Test-Path $targetFileExtraction) { throw New-Object System.ArgumentException ("Target file for extracted part '{0}' already exists." -f $targetFileExtraction) }
if (Test-Path $targetFileRemainder) { throw New-Object System.ArgumentException ("Target file for remainder part '{0}' already exists." -f $targetFileExtraction) }

$totalSourceLines = (Get-Content $sourceFile).Count

if ($end -gt $totalSourceLines) { throw New-Object System.ArgumentException ("The source file has only {0} lines, but the end line number is {1}." -f $totalSourceLines, $end) }

# Tweak start and end line so that they are zero-based
# for better array indexing.
# -
$start = $start - 1
$end = $end - 1

# Calculate other important line numbers and counts, all zero-based.
# -
$remainderHeadStartLine = 1
$remainderHeadEndLine = $start - 1
$remainderHeadTotalLines = $remainderHeadEndLine - $remainderHeadStartLine + 1

$remainderTailStartLine = $end + 1
$remainderTailEndLine = $totalSourceLines - 1
$remainderTailTotalLines = $remainderTailEndLine - $remainderTailStartLine + 1

$hasHead = ($remainderHeadTotalLines -gt 0)
$hasTail = ($remainderTailTotalLines -gt 0)

if (!$hasHead -And !$hasTail)
{
    throw New-Object System.ArgumentException ("There is no point running this script as the source file will become empty after extraction.")
}

$extractedTotalLines = $end - $start + 1

echo $remainderHeadTotalLines
echo $remainderTailTotalLines
echo $extractedTotalLines

git status

if (-not $?)
{
    throw New-Object System.ArgumentException "The script running location is not a git repository."
}

git ls-files $sourceFile --error-unmatch

if (-not $?)
{
    throw New-Object System.ArgumentException ("Source file '{0}' is not located inside the repository." -f $sourceFile)
}

$originalBranchName = &git rev-parse --abbrev-ref HEAD
git checkout $originalBranchName

if (-not $?)
{
    throw New-Object System.ArgumentException "Could not obtain the name of the current branch."
}

$sourceFileNameOnly = (Split-Path $sourceFile -leaf)

# Test that the target files can be actually created and
# will be located in the repository. For that, we create it and
# use git ls-files with allow untracked (-o) switch to check that 
# it exists in the repository. We will delete it afterwards.
# -
New-Item $targetFileExtraction
$targetFileExtractionNameOnly = (Split-Path $targetFileExtraction -leaf)

if (Test-Path $targetFileRemainder) 
{ 
    throw New-Object System.ArgumentException ("Target file for remainder part is the same as the target file for the extracted part." -f $targetFileExtraction) 
}

git ls-files -o $targetFileExtraction --error-unmatch

Try
{
    if (-not $?)
    {
        throw New-Object System.ArgumentException ("Target file for the extracted part '{0}' would not be located inside the repository." -f $targetFileExtraction)
    }
}
Finally
{
    Remove-Item $targetFileExtraction
}

New-Item $targetFileRemainder
$targetFileRemainderNameOnly = (Split-Path $targetFileRemainder -leaf)

git ls-files -o $targetFileRemainder --error-unmatch

Try
{
    if (-not $?)
    {
        throw New-Object System.ArgumentException ("Target file for the remainder part '{0}' would not be located inside the repository." -f $targetFileRemainder)
    }
}
Finally
{
    Remove-Item $targetFileRemainder
}

function cleanupBranches
{
    git branch -D $temporaryBranchName1
    git branch -D $temporaryBranchName2
}

cleanupBranches 2>$null

$sourceFileContent = Get-Content $sourceFile
if (-not $?) { throw New-Object System.ArgumentException ("Could not read contents of the source file '{0}'." -f $sourceFile) }

Try
{
    # Move the extracted part into its location.
    # -
    git checkout -b $temporaryBranchName1
    if (-not $?) { throw New-Object System.ArgumentException ("Could not checkout temporary branch 1 '{0}'." -f $temporaryBranchName1) }

    git mv $sourceFile $targetFileExtraction
    if (-not $?) { throw New-Object System.ArgumentException "Could not move the extracted part to the target file." }

    git add -A
    git commit -a -m ("{0} file {1} to {2}, future extracted part" -f $commitPrefix, $sourceFileNameOnly, $targetFileExtractionNameOnly)

    if (-not $?) { throw New-Object System.ArgumentException "Could not commit the changes in the temporary branch 1." }
    
    # Move the remainder part into its location.
    # -
    git checkout $originalBranchName
    if (-not $?) { throw New-Object System.ArgumentException ("Could not checkout original branch '{0}'." -f $originalBranchName) }

    git checkout -b $temporaryBranchName2
    if (-not $?) { throw New-Object System.ArgumentException ("Could not checkout temporary branch 2 '{0}'.", $temporaryBranchName2) }

    git mv $sourceFile $targetFileRemainder
    if (-not $?) { throw New-Object System.ArgumentException "Could not move the remainder part to the target file." }

    git add -A
    git commit -a -m ("{0} file {1} to {2}, future remainder part" -f $commitPrefix, $sourceFileNameOnly, $targetFileExtractionNameOnly)

    # Handle the merge conflict
    # -
    git checkout $originalBranchName
    if (-not $?) { throw New-Object System.ArgumentException ("Could not checkout original branch '{0}'." -f $originalBranchName) }

    git merge --no-ff $temporaryBranchName1
    git merge --no-ff $temporaryBranchName2

    git add -A
    git rm $sourceFile
    git commit -a -m ("{0} add the extracted and remainder part into the main branch" -f $commitPrefix)

    # Tweak the file contents
    # -
    Set-Content $targetFileExtraction -Force -Encoding UTF8 -Value ($sourceFileContent[($start)..($end)])

    Set-Content $targetFileRemainder -Force -Encoding UTF8 -Value ""

    if ($hasHead)
    {
        Add-Content $targetFileRemainder -Force -Encoding UTF8 -Value ($sourceFileContent[($remainderHeadStartLine)..($remainderHeadEndLine)])
    }

    if ($hasTail)
    {
        Add-Content $targetFileRemainder -Force -Encoding UTF8 -Value ($sourceFileContent[($remainderTailStartLine)..($remainderTailEndLine)])
    }

    # Move back the original file if it should have the original name.
    # -
    if (!$remainderDiffers)
    {
        git mv $targetFileRemainder $sourceFile
        if (-not $?) { throw New-Object System.ArgumentException "Could not rename the remainder part back the original name." }

        git add -A
        git commit -a -m ("{0} rename temporary file {1} back to {2}" -f $commitPrefix, $targetFileRemainderNameOnly, $sourceFileNameOnly)
    }

    # Commit the final changes
    # -
    git add -A

    if ($remainderDiffers)
    {
        git commit -a -m ("{0} split file {1} into {2} and {3}" -f $commitPrefix, $sourceFileNameOnly, $targetFileExtractionNameOnly, $targetFileRemainderNameOnly)
    }
    else 
    {
        git commit -a -m ("{0} extract lines {1}-{2} of file {3} to {4}" -f $commitPrefix, $start, $end, $sourceFileNameOnly, $targetFileExtractionNameOnly)        
    }
}
Finally
{
    git reset --hard
    git checkout $originalBranchName
    git reset --hard
    cleanupBranches 2>$null
}