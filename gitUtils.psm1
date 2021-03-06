# Git functions
# Mark Embling (http://www.markembling.info/)

# Is the current directory a git repository/working copy?
function isCurrentDirectoryGitRepository {
    if ((Test-Path ".git") -eq $TRUE) {
        return $TRUE
    }
    
    # Test within parent dirs
    $checkIn = (Get-Item .).parent
    while ($checkIn -ne $NULL) {
        $pathToTest = $checkIn.fullname + '/.git'
        if ((Test-Path $pathToTest) -eq $TRUE) {
            return $TRUE
        } else {
            $checkIn = $checkIn.parent
        }
    }
    
    return $FALSE
}

# Get the current branch
function gitBranchName {
    $currentBranch = ''
    git branch | foreach {
        if ($_ -match "^\* (.*)") {
            $currentBranch += $matches[1]
        }
    }
    return $currentBranch
}

# Extracts status details about the repo
function gitStatus {
    $untracked = $FALSE
    $added = 0
    $modified = 0
    $deleted = 0
    $ahead = $FALSE
    $aheadCount = 0
    
    $output = git status
    
    $branchbits = $output[0].Split(' ')
    $branch = $branchbits[$branchbits.length - 1]
    
    $output | foreach {
        if ($_ -match "^\#.*origin/.*' by (\d+) commit.*") {
            $aheadCount = $matches[1]
            $ahead = $TRUE
        }
        elseif ($_ -match "deleted:") {
            $deleted += 1
        }
        elseif (($_ -match "modified:") -or ($_ -match "renamed:")) {
            $modified += 1
        }
        elseif ($_ -match "new file:") {
            $added += 1
        }
        elseif ($_ -match "Untracked files:") {
            $untracked = $TRUE
        }
    }
    
    return @{"untracked" = $untracked;
             "added" = $added;
             "modified" = $modified;
             "deleted" = $deleted;
             "ahead" = $ahead;
             "aheadCount" = $aheadCount;
             "branch" = $branch}
}

function gitBranchInfo {
    if (isCurrentDirectoryGitRepository) {
        $status = gitStatus
        $currentBranch = $status["branch"]
        
        Write-Host(' [') -nonewline -foregroundcolor Black
        if ($status["ahead"] -eq $FALSE) {
            # We are not ahead of origin
            Write-Host($currentBranch) -nonewline -foregroundcolor Red
        } else {
            # We are ahead of origin
            Write-Host($currentBranch) -nonewline -foregroundcolor Green
        }
        Write-Host(' +' + $status["added"]) -nonewline -foregroundcolor Blue
        Write-Host(' ~' + $status["modified"]) -nonewline -foregroundcolor Blue
        Write-Host(' -' + $status["deleted"]) -nonewline -foregroundcolor Blue
        
        if ($status["untracked"] -ne $FALSE) {
            Write-Host(' !') -nonewline -foregroundcolor Blue
        }
        
        Write-Host(']') -nonewline -foregroundcolor Blue 
    } else {
        Write-Host('[ !git folder ]') -nonewline -foregroundcolor Blue 
    }
    return " "
}

function prompt {
	$path = ""
	$pathbits = ([string]$pwd).split("\", [System.StringSplitOptions]::RemoveEmptyEntries)
	if($pathbits.length -eq 1) {
		$path = $pathbits[0] + "\"
	} else {
		$path = $pathbits[$pathbits.length - 1]
	}
	$userLocation = $env:username + '@' + [System.Environment]::MachineName + ' ' + $path
    Write-Host($userLocation) -nonewline -foregroundcolor Green 

    gitBranchInfo
    
	Write-Host('>') -nonewline -foregroundcolor Black    
	return " "
}

function gitCommands($filter) {
  $cmdList = @()
  $output = git help
  foreach($line in $output) {
    if($line -match '^   (S+) (.*)') {
      $cmd = $matches[1]
      if($filter -and $cmd.StartsWith($filter)) {
        $cmdList += $cmd.Trim()
      }
      elseif(-not $filter) {
        $cmdList += $cmd.Trim()
      }
    }
  }
 
  $cmdList | sort
 }
 
function gitRemotes($filter) {
  if($filter) {
    git remote | where { $_.StartsWith($filter) }
  }
  else {
    git remote
  }
}
 
function gitLocalBranches($filter) {
   git branch | foreach { 
      if($_ -match "^*?s*(.*)") { 
        if($filter -and $matches[1].StartsWith($filter)) {
          $matches[1]
        }
        elseif(-not $filter) {
          $matches[1]
        }
      } 
   }
}

Register-TabExpansion "git" ($line, $lastWord) {
  $LineBlocks = [regex]::Split($line, '[|;]')
  $lastBlock = $LineBlocks[-1] 
 
  switch -regex ($lastBlock) {
    'git (.*)' { gitTabExpansion($lastBlock) }
  }
}

function gitTabExpansion($lastBlock) {
     switch -regex ($lastBlock) {
 
        #Handles git branch -x -y -z <branch name>
        'git branch -(d|D) (S*)$' {
          gitLocalBranches($matches[2])
        }
 
        #handles git checkout <branch name>
        #handles git merge <brancj name>
        'git (checkout|merge) (S*)$' {
          gitLocalBranches($matches[2])
        }
 
        #handles git <cmd>
        #handles git help <cmd>
        'git (help )?(S*)$' {      
          gitCommands($matches[2])
        }
 
        #handles git push remote <branch>
        #handles git pull remote <branch>
        'git (push|pull) (S+) (S*)$' {
          gitLocalBranches($matches[3])
        }
 
        #handles git pull <remote>
        #handles git push <remote>
        'git (push|pull) (S*)$' {
          gitRemotes($matches[2])
        }
    }	
}

Export-ModuleMember -function isCurrentDirectoryGitRepository
Export-ModuleMember -function gitBranchName
Export-ModuleMember -function gitStatus
Export-ModuleMember -function gitBranchInfo
Export-ModuleMember -function prompt
Export-ModuleMember -function gitCommands
Export-ModuleMember -function gitRemotes
Export-ModuleMember -function gitLocalBranches
Export-ModuleMember -function gitTabExpansion