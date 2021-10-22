$NEWLINE = [System.Environment]::NewLine
$REMOVE_EMPTY_LINE = {
    param ([string] $Text )
    $Text.Split("$NEWLINE", [StringSplitOptions]::RemoveEmptyEntries) -join "$NEWLINE"
}
$REPO_LIST = [ordered] @{
    public = (Resolve-Path '..\public').Path;
    private = (Resolve-Path '..\private').Path
}

class Repository {
    $EmailWatcher

    Repository($FullPath) {
        $this.EmailWatcher = [System.IO.FileSystemWatcher] $FullPath
    }

    static $BlankEmail = $(
            $BlankEmailPathInfo = (Resolve-Path '..\public\blank-email.html');
            $AddMemberParams = @{
                InputObject = $BlankEmailPathInfo;
                MemberType = 'NoteProperty';
                Name = 'Content';
                Value = "$(Get-Content -Path $BlankEmailPathInfo.Path -Raw -Force)"
            }
            Add-Member @AddMemberParams -PassThru
        )

    static [scriptblock] WatchEmail() {
        return {
            $NewEmail = ($Event.SourceArgs)[1].FullPath
            if (($NewEmail -like '*-email.html') -and ((Get-Content -Path $NewEmail).Count -eq 0)) {
                [Repository]::BlankEmail.Content | Out-File -FilePath $NewEmail
            }
        }
    }

    [void] RegisterWatchEmail() {
        $RegisterObjectEventParams = @{
            InputObject = $this.EmailWatcher;
            Action = [Repository]::WatchEmail()
        }
        & {
            Register-ObjectEvent @RegisterObjectEventParams -EventName Created
            Register-ObjectEvent @RegisterObjectEventParams -EventName Renamed
        } | Out-Null
    }
}

$PublicRepo = [Repository]::new($REPO_LIST.public)
$PrivateRepo = [Repository]::new($REPO_LIST.private)

$PublicRepo.RegisterWatchEmail()
$PrivateRepo.RegisterWatchEmail()

Register-ObjectEvent -InputObject $PublicRepo.EmailWatcher -EventName Changed -Action {
    if (($Event.SourceArgs)[1].FullPath -eq ([Repository]::BlankEmail.Path)) {
        $BlankEmailContent = Get-Content -Path ([Repository]::BlankEmail.Path) -Raw -Force
        if ($BlankEmailContent.Count -gt 0) {
            Get-ChildItem -Path ([array] $REPO_LIST.Values) -Filter '*-email.html' |
            Where-Object -Property FullName -NE ([Repository]::BlankEmail.Path) |
            ForEach-Object {
                $EmailContent = Get-Content -Path $_.FullName -Raw
                if (($EmailContent.Count -eq 0) -or $(
                    $EmailContent = & $REMOVE_EMPTY_LINE -Text $EmailContent
                    $TempContentUsedForComparison = & $REMOVE_EMPTY_LINE -Text ([Repository]::BlankEmail.Content)
                    $EmailContent -eq $TempContentUsedForComparison
                )) {
                    $BlankEmailContent | Out-File $_.FullName
                }
            }
            [Repository]::BlankEmail.Content = $BlankEmailContent
        }
    }
} | Out-Null