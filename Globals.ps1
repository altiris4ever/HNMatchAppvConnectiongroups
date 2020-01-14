#--------------------------------------------
# Declare Global VariabRead and Functions here
#--------------------------------------------


#Sample function that provides the location of the script
function Get-ScriptDirectory
{
<#
	.SYNOPSIS
		Get-ScriptDirectory returns the proper location of the script.

	.OUTPUTS
		System.String
	
	.NOTES
		Returns the correct path within a packaged executable.
#>
	[OutputType([string])]
	param ()
	if ($null -ne $hostinvocation)
	{
		Split-Path $hostinvocation.MyCommand.path
	}
	else
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}

#Sample variable that provides the location of the script
[string]$ScriptDirectory = Get-ScriptDirectory


Function Msg-User {
	Param (
		[String]$MsgHead,
		[Array]$Msg,
		[string]$Action = 'OKCancel'
		#'OK', 'AbortRetryIgnore', 'YesNoCancel', 'YesNo', 'RetryCancel'.''
	)
	For ($i = 0; $i -lt $Msg.count; $i++)
	{
		$msg[$i] += "`r`n "
	}
	
	Return [System.Windows.MessageBox]::Show($msg, $MsgHead, $Action, 'Asterisk')
}

#region XML

Function Get-XmlFromAppV {
	Param (
		[string]$folder,
		[string]$AppvPakke
	)
	$AppxManifest = $folder + "\AppxManifest.xml"
	If (Test-Path $AppxManifest) { Remove-Item $AppxManifest | Out-Null }
	$arg1 = $folder + "\" + $AppvPakke
	$arg3 = 'AppxManifest.xml'
	$arg4 = '-o"' + $folder + '"'
	$arg5 = '-y'
	$b = $Global:wkApp + "\7-Zip\7z.exe"
	#Write-Host $b 'x' $arg1"|"$arg3"|"$arg4"|" '-bso0' '-bse0' '-aoa' '-bd' '-y'
	&$b 'x' $arg1 $arg3 $arg4 '-bso0' '-bse0' '-aoa' '-bd' '-y'
	Return (Test-Path $AppxManifest)
}

Function Get-AppxManifestXml {
	Param (
		[string]$xmlfile
	)
	[int]$Global:NsNr = 0
	[array]$Global:NsNames = @()
	[hashtable]$Global:NsNa = @{ }
	[hashtable]$Global:NsNode = @{ }
	[hashtable]$Global:NodeType = @{ }
	[array]$Global:Allnodes = @{ }
	$a = (Read-AppxManifestXml -xmlfile $xmlfile)
	If ($a -eq 'ok') {
		$Global:Allnodes = $Global:Allnodes | sort-Object
		Return $Global:Allnodes
	} Else {
		Return $a
	}
}


Function Get-Endenode {
	Param (
		[string]$NodePath
	)
	#Check for nodenames containing [ .'] or ending with ['] - ( That's what's inside [])
	If ($NodePath -match ".'" -and $NodePath.EndsWith("'")) {
		$AttributeName = $NodePath.Split('.')[-2 .. -1] -join { '.' } | ForEach-Object{ $_.replace("'", '') }
	} Else {
		$AttributeName = $NodePath.Split('.')[-1]
	}
	Return $AttributeName
}

Function Get-NsName {
	$Global:NsNr += 1
	$nsName = 'a' + $Global:NsNr
	$Global:NsNames += $nsName
	Return $nsName
}

Function Get-XmlElementsAttributeValue {
	Param (
		[string]$NodePath,
		[string]$DeleteAttributes = 'N'
	)
	$c = 1
	If ($NodePath -match ".'" -and $NodePath.EndsWith("'")) {
		$AttributeName = $NodePath.Split('.')[-2 .. -1] -join { '.' } | ForEach-Object{ $_.replace("'", '') }
		$c = 3
	} Else {
		$AttributeName = $NodePath.Split('.')[-1]
	}
	$NodePath = $NodePath.Substring(0, $NodePath.Length - $AttributeName.Length - $c)
	[string]$fullyQualifiedNodePath = Set-FullyQualifiedXmlNodePath -NodePath $NodePath
	$node = $Global:xml.SelectSingleNode($fullyQualifiedNodePath, $Global:ns)
	If ($node -and $node.$AttributeName) {
		If ($DeleteAttributes -ne 'N') {
			$node.RemoveAttribute($AttributeName)
			Return $null
		} Else { Return $node.$AttributeName }
	} Else { Return $null }
}

Function Get-XmlNode {
	Param (
		[string]$NodePath,
		[string]$Childnodes = ''
	)
	[string]$fullyQualifiedNodePath = Set-FullyQualifiedXmlNodePath -NodePath $NodePath
	If ($Childnodes -ne '') {
		$Global:xml.SelectSingleNode($fullyQualifiedNodePath, $Global:ns).ChildNodes >$Childnodes
	}
	$node = $Global:xml.SelectSingleNode($fullyQualifiedNodePath, $Global:ns)
	Return $node
}

Function Get-XmlNodesDeskNy {
	Param (
		[string]$NodePath,
		[string]$Filech = '',
		[string]$Filenode = ''
	)
	[string]$a = Set-FullyQualifiedXmlNodePath $NodePath
	[string[]]$n = (($Global:Xml.SelectNodes($a, $Global:ns) | Get-Member -MemberType Property | Format-Table -Property name) | out-string -stream) -notmatch '^$' | Select-Object -Skip 2
	[string[]]$d = (($Global:Xml.SelectNodes($a, $Global:ns) | Get-Member -MemberType Property | Format-Table -Property definition) | out-string -stream) -notmatch '^$' | Select-Object -Skip 2
	$tmp2 = '.'
	$Node = Get-XmlNode -NodePath $NodePath -Childnodes $filCn
	If ($NodePath -eq '') { $tmp2 = '' }
	For ($j = 0; $j -lt $n.Count; $j++) {
		$tmp = 'com'
		#Hrite-Host '275 j:'$j           
		If ($n[$j].split('.').count -gt 1) { $n[$j] = "'" + [string]$n[$j].trim() + "'" }
		#if ($d[$j] -like 'system.object*'){$tmp='obj.'}
		If ($d[$j] -like 'system*') { $tmp = 'xml.' }
		If ($n[$j] -like '#commen*') { $tmp = 'com.' }
		If ($d[$j] -like 'string*') { $tmp = 'val.' }
		If ($tmp -eq 'xml.') {
			$p = $NodePath + $tmp2 + [string]$n[$j].Trim()
			$q = $p.Split('.')[-1]
			$nsValue = $node.$q.NamespaceURI
			#Hrite-Host '284'$p'| ns:'$nsValue'-'
			$tmp3 = Set-NsName -NsValue $nsValue -NodePath $p
			$c = Get-XmlNode -NodePath $p
			[string]$b = $c.NodeType
			If ($b -eq 'Element' -or $b -eq 'Document') {
				$tmp = 'xml.'
			} Else {
				$tmp = 'val.'
				#Hrite-Host '296 Nodetype:'$b 'j:'$j
			}
		}
		$n[$j] = $tmp + $NodePath + $tmp2 + [string]$n[$j].Trim()
		$d[$j] = $d[$j] + ' | ' + $n[$j]
	}
	If ($Filenode -ne '') {
		$d | out-file $Filenode
	}
	Return [array]$n
}

Function Get-XmlValCom {
	Param (
		[array]$Found,
		[String]$Chk
	)
	[array]$n = @()
	For ($j = 0; $j -lt $Found.Count; $j++) {
		[string]$h = $Found[$j]
		[int]$q = $h.Length
		If ($h.Length -igt 3) {
			#Hrite-Host 'h:'$h' Chk:'$Chk' l:'$q
			If ($h.Substring(0, 4) -eq $Chk) {
				$n += [string]$h.Substring(4, $h.Length - 4)
			}
		}
	}
	Return $n
}
Function Read-AppxManifestXml {
	Param (
		[string]$xmlfile
	)
	If (-not (Test-Path $xmlfile)) {
		Return ('Can't find:' + $xmlfile)
	}
	$Forst = 0
	[xml]$Global:Xml = get-content -Path $XmlFile
	[System.Xml.XmlNamespaceManager]$Global:Ns = New-Object System.Xml.XmlNamespaceManager($Global:xml.NameTable)
	$a = Set-NsName -NsValue $Global:Xml.DocumentElement.NamespaceURI -NodePath '/'
	$Global:Allnodes = @()
	$XmlNoder = @()
	$ValNoder = @()
	$ComNoder = @()
	$FoundNodes = @('xml.')
	Do {
		$fil = ''
		[array]$Global:Allnodes += $FoundNodes | ForEach-Object{ If ($_ -ne 'val.xml') { $_ } }
		#$chknodes = @()
		[array]$chknodes = Get-XmlValCom -Found $FoundNodes -Chk 'xml.'
		If ($Forst -lt 3) {
			Write-Host $Forst '<-- nr : chknodes -->' $chknodes ' GA:' $Global:Allnodes
		}
		
		If ($Forst -eq 1) {
			Write-Host $global:XmlNode
			$Global:XmlNode = $chknodes[0]
		}
		
		$Forst += 1
		If ($chknodes.count -lt 1) { Break }
		[array]$XmlNoder += $chknodes
		[array]$TmpNodes = Get-XmlValCom -Found $FoundNodes -Chk 'val.'
		If ($TmpNodes.Count -gt 0) { [array]$ValNoder += $TmpNodes }
		[array]$TmpNodes = Get-XmlValCom -Found $FoundNodes -Chk 'com.'
		If ($TmpNodes.Count -gt 0) { [array]$ComNoder += $TmpNodes }
		$FoundNodes = @()
		For ($i = 0; $i -lt $chknodes.Count; $i++) {
			$noden = [string]$chknodes[$i]
			$Filenode = ''
			$Filech = ''
			$TmpNodes = Get-XmlNodesDeskNy -NodePath $noden -Filech $Filech -Filenode $Filenode
			$Fil = ''
			$FoundNodes += $TmpNodes
		}
	} Until ($FoundNodes.count -lt 1)
	Return ('ok')
	
	$XmlNodesRap = @()
	$a = $null
	For ($i = 1; $i -lt $Xmlnoder.Count; $i++) {
		[string]$q = $Xmlnoder[$i]
		[string]$fullyQualifiedNodePath = Set-FullyQualifiedXmlNodePath -NodePath $q
		$XmlNodesRap += '--- ' + $q + '----'
		$XmlNodesRap += $Global:xml.SelectSingleNode($fullyQualifiedNodePath, $Global:ns)
	}
	$Fil = $Global:Folders.Root + 'xmlnodesRap.txt'
	$XmlNodesRap >$Fil
	$VerdiNodesRap = @()
	For ($i = 1; $i -lt $ValNoder.Count; $i++) {
		[string]$q = $ValNoder[$i]
		$Res = Get-XmlElementsAttributeValue -NodePath $q
		$Res = $Res | ForEach-Object{ $q + ' : ' + $_ }
		$VerdiNodesRap += $Res
	}
	$Fil = $Global:Folders + 'VerdinodesRap.txt'
	$VerdiNodesRap >$Fil
}

Function Read-AppxManifestXml {
	Param (
		[string]$xmlfile
	)
	If (-not (Test-Path $xmlfile)) {
		Return ('Can't find:' + $xmlfile)
	}
	$Forst = 0
	[xml]$Global:Xml = get-content -Path $XmlFile
	[System.Xml.XmlNamespaceManager]$Global:Ns = New-Object System.Xml.XmlNamespaceManager($Global:xml.NameTable)
	$a = Set-NsName -NsValue $Global:Xml.DocumentElement.NamespaceURI -NodePath '/'
	$Global:Allnodes = @()
	$XmlNoder = @()
	$ValNoder = @()
	$ComNoder = @()
	$FoundNodes = @('xml.')
	Do {
		$fil = ''
		[array]$Global:Allnodes += $FoundNodes | ForEach-Object{ If ($_ -ne 'val.xml') { $_ } }
		[array]$chknodes = Get-XmlValCom -Found $FoundNodes -Chk 'xml.'
		If ($Forst -lt 3) {
			#Write-Host $Forst '<-- nr : chknodes -->' $chknodes ' GA:' $Global:Allnodes
		}
		
		If ($Forst -eq 1) { $Global:XmlNode = $chknodes[0] }
		
		$Forst += 1
		If ($chknodes.count -lt 1) { Break }
		[array]$XmlNoder += $chknodes
		[array]$TmpNodes = Get-XmlValCom -Found $FoundNodes -Chk 'val.'
		If ($TmpNodes.Count -gt 0) { [array]$ValNoder += $TmpNodes }
		[array]$TmpNodes = Get-XmlValCom -Found $FoundNodes -Chk 'com.'
		If ($TmpNodes.Count -gt 0) { [array]$ComNoder += $TmpNodes }
		$FoundNodes = @()
		For ($i = 0; $i -lt $chknodes.Count; $i++) {
			$noden = [string]$chknodes[$i]
			$Filenode = ''
			$Filech = ''
			$TmpNodes = Get-XmlNodesDeskNy -NodePath $noden -Filech $Filech -Filenode $Filenode
			$Fil = ''
			$FoundNodes += $TmpNodes
		}
	} Until ($FoundNoder.count -lt 1)
	Return ('ok')
}

Function Set-FullyQualifiedXmlNodePath {
	Param (
		[String]$NodePath
	)
	If ($Nodepath -eq '') { Return '/' }
	[array]$a = $NodePath.Split('.')
	[int]$b = $NodePath.Split('.').count
	[string]$c = ''
	[string]$d = ''
	For ($i = 0; $i -lt $b; $i++) {
		$d += $a[$i]
		$c += '/' + $Global:NsNode.$d + ':' + $a[$i]
	}
	Return $c
}

Function Set-NodeType {
	Param (
		$Ntype,
		[string]$NodePath
	)
	$nodename = $NodePath
	#Hrite-Host $q ':' $Found[$j]":" $p
	If ($nodename -like ".") {
		$nodename = $nodename | ForEach-Object{ $_.replace('.', '') }
	}
	#Hrite-Host 'Ntype:'$nodename
	$Glabal:NodeType.Add($nodename, $NType)
	Return 'ok'
}

Function Set-NsName {
	Param (
		[String]$NsValue,
		[String]$NodePath
	)
	
	If ($NsValue.Length -lt 4) {
		$NsValue = $Global:NsNa.[string]$Global:NsNames[0]
		#Hrite-Host '63':$NodePath
	}
	If ($NsValue.Length -gt 100) {
		$NsValue = $Global:NsNa.[string]$Global:NsNames[0]
		#Hrite-Host '63':$NsValue
	}
	
	$a = 0
	$c = $NodePath.Split('.').Count
	For ($j = 0; $j -lt $Global:NsNames.Count; $j++) {
		If ($Global:NsNa.[string]$Global:NsNames[$j] -eq $NsValue) { $a = 1; Break }
	}
	$nsName = 'a' + ($j + 1)
	$nodename = $Nodepath
	If ($c -gt 1) { $nodename = $NodePath | ForEach-Object{ $_.replace('.', '') } }
	If ($a -eq 0) {
		#Hrite-Host '77'$NsValue
		#Hrite-Host '77'$NodePath
		#Pause
		$b = Get-NsName
		$Global:NS.AddNamespace($b, $nsValue)
		$nsName = 'a' + $Global:NsNr
		$Global:NsNa.Add($nsName, $nsValue)
	}
	$Global:NsNode.Add($nodename, $nsName)
	#Hrite-Host '86'$nodename' :'$nsName
	Return 'ok'
}
$Global:Wk = ''

#------ HjelpArrays for Xml ------
[xml]$Global:xml = New-Object System.Xml.XmlDocument
[int]$Global:NsNr = 0
[array]$Global:NsNames = @()
[hashtable]$Global:NsNa = @{ }
[hashtable]$Global:NsNode = @{ }
[hashtable]$Global:NodeType = @{ }
[array]$Global:Allnodes = @()
[string]$Global:AppvFile = ''
#$global:FF = @{ }
#endregion