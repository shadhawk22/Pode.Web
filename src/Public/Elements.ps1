function New-PodeWebTextbox {
    [CmdletBinding(DefaultParameterSetName = 'Single')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(ParameterSetName = 'Single')]
        [ValidateSet('Text', 'Email', 'Password', 'Number', 'Date', 'Time', 'File', 'DateTime')]
        [string]
        $Type = 'Text',

        [Parameter()]
        [string]
        $Placeholder,

        [Parameter(ParameterSetName = 'Multi')]
        [Alias('Height')]
        [int]
        $Size = 4,

        [Parameter()]
        [string]
        $Width = 100,

        [Parameter()]
        [string]
        $HelpText,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $PrependText,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $PrependIcon,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $AppendText,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $AppendIcon,

        [Parameter(ValueFromPipeline = $true)]
        [object[]]
        $Value,

        [Parameter(ParameterSetName = 'Single')]
        [scriptblock]
        $AutoComplete,

        [Parameter()]
        [string[]]
        $EndpointName,

        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxLength = 524288,

        [Parameter(ParameterSetName = 'Multi')]
        [switch]
        $Multiline,

        [switch]
        $Preformat,

        [switch]
        $ReadOnly,

        [switch]
        $Disabled,

        [Parameter(ParameterSetName = 'Single')]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [switch]
        $Required,

        [switch]
        $AutoFocus,

        [switch]
        $DynamicLabel,

        [switch]
        $AsJson,

        [Parameter(ParameterSetName = 'Multi')]
        [switch]
        $JsonInline
    )

    begin {
        $items = @()
    }

    process {
        $items += $Value
    }

    end {
        if (!$AsJson -and ($items.Length -gt 0)) {
            $items = ($items | Out-String).Trim()
        }

        $Id = Get-PodeWebElementId -Tag Textbox -Id $Id -Name $Name

        # constrain number of lines shown
        if ($Size -le 0) {
            $Size = 4
        }

        # build element
        $element = @{
            Operation        = 'New'
            ComponentType    = 'Element'
            ObjectType       = 'Textbox'
            Name             = $Name
            DisplayName      = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
            ID               = $Id
            Type             = $Type
            Multiline        = $Multiline.IsPresent
            Placeholder      = $Placeholder
            Size             = $Size
            Width            = (ConvertTo-PodeWebSize -Value $Width -Default 'auto' -Type '%')
            Preformat        = $Preformat.IsPresent
            HelpText         = [System.Net.WebUtility]::HtmlEncode($HelpText)
            ReadOnly         = $ReadOnly.IsPresent
            Disabled         = $Disabled.IsPresent
            IsAutoComplete   = ($null -ne $AutoComplete)
            Value            = $items
            Prepend          = @{
                Enabled = (![string]::IsNullOrWhiteSpace($PrependText) -or ![string]::IsNullOrWhiteSpace($PrependIcon))
                Text    = $PrependText
                Icon    = $PrependIcon
            }
            Append           = @{
                Enabled = (![string]::IsNullOrWhiteSpace($AppendText) -or ![string]::IsNullOrWhiteSpace($AppendIcon))
                Text    = $AppendText
                Icon    = $AppendIcon
            }
            NoAuthentication = $NoAuthentication.IsPresent
            Required         = $Required.IsPresent
            AutoFocus        = $AutoFocus.IsPresent
            DynamicLabel     = $DynamicLabel.IsPresent
            MaxLength        = $MaxLength
            AsJson           = $AsJson.IsPresent
            JsonInline       = $JsonInline.IsPresent
        }

        # create autocomplete route
        $routePath = "/pode.web-dynamic/elements/textbox/$($Id)/autocomplete"
        if (($null -ne $AutoComplete) -and !(Test-PodeWebRoute -Path $routePath)) {
            # check for scoped vars
            $AutoComplete, $autoUsingVars = Convert-PodeScopedVariables -ScriptBlock $AutoComplete -PSSession $PSCmdlet.SessionState
            $autoLogic = @{
                ScriptBlock    = $AutoComplete
                UsingVariables = $autoUsingVars
            }

            $auth = $null
            if (!$NoAuthentication -and !$PageData.NoAuthentication) {
                $auth = (Get-PodeWebState -Name 'auth')
            }

            if (Test-PodeIsEmpty $EndpointName) {
                $EndpointName = Get-PodeWebState -Name 'endpoint-name'
            }

            $argList = @(
                $element,
                $ElementData,
                $autoLogic
            )

            Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
                param($Element, $Parent, $Logic)
                $global:ElementData = $Element
                $global:ParentData = $Parent
                Set-PodeWebMetadata

                Write-PodeJsonResponse -Value @{
                    Values = (Invoke-PodeWebScriptBlock -Logic $Logic)
                }

                $global:ElementData = $null
                $global:ParentData = $null
            }
        }

        return $element
    }
}

function New-PodeWebFileUpload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string[]]
        $Accept = '*/*',

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag File -Id $Id -Name $Name

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'File-Upload'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        Accept        = ($Accept -join ',')
        NoEvents      = $true
        Required      = $Required.IsPresent
    }
}

function New-PodeWebParagraph {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'Value')]
        [string]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [hashtable[]]
        $Content,

        [Parameter()]
        [ValidateSet('Left', 'Right', 'Center')]
        [string]
        $Alignment = 'Left'
    )

    # ensure elements are correct
    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Paragraph can only contain other elements'
    }

    $Id = Get-PodeWebElementId -Tag Para -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Paragraph'
        ID            = $Id
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        Content       = $Content
        Alignment     = $Alignment.ToLowerInvariant()
        NoEvents      = $true
    }
}

function New-PodeWebCodeBlock {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Language = [string]::Empty,

        [switch]
        $Scrollable,

        [switch]
        $NoHighlight
    )

    # id
    $Id = Get-PodeWebElementId -Tag Codeblock -Id $Id

    # language
    if ($NoHighlight) {
        $Language = 'plaintext'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'CodeBlock'
        ID            = $Id
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        Language      = $Language.ToLowerInvariant()
        Scrollable    = $Scrollable.IsPresent
        NoEvents      = $true
    }
}

function New-PodeWebCode {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Value
    )

    $Id = Get-PodeWebElementId -Tag Code -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Code'
        ID            = $Id
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        NoEvents      = $true
    }
}

function New-PodeWebCheckbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(ParameterSetName = 'Multiple')]
        [string[]]
        $Options,

        [Parameter(ParameterSetName = 'Multiple')]
        [string[]]
        $DisplayOptions,

        [Parameter(ParameterSetName = 'Multiple')]
        [switch]
        $Inline,

        [switch]
        $AsSwitch,

        [switch]
        $Checked,

        [switch]
        $Disabled,

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag Checkbox -Id $Id -Name $Name

    if (($null -eq $Options) -or ($Options.Length -eq 0)) {
        $Options = @('true')
    }

    return @{
        Operation      = 'New'
        ComponentType  = 'Element'
        ObjectType     = 'Checkbox'
        Name           = $Name
        DisplayName    = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID             = $Id
        Options        = @($Options)
        DisplayOptions = @(Protect-PodeWebValues -Value $DisplayOptions -Default $Options -EqualCount -Encode)
        Inline         = $Inline.IsPresent
        AsSwitch       = $AsSwitch.IsPresent
        Checked        = $Checked.IsPresent
        Disabled       = $Disabled.IsPresent
        Required       = $Required.IsPresent
    }
}

function New-PodeWebRadio {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Options,

        [Parameter()]
        [string[]]
        $DisplayOptions,

        [switch]
        $Inline,

        [switch]
        $Disabled,

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag Radio -Id $Id -Name $Name

    return @{
        Operation      = 'New'
        ComponentType  = 'Element'
        ObjectType     = 'Radio'
        Name           = $Name
        DisplayName    = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID             = $Id
        Options        = @($Options)
        DisplayOptions = @(Protect-PodeWebValues -Value $DisplayOptions -Default $Options -EqualCount -Encode)
        Inline         = $Inline.IsPresent
        Disabled       = $Disabled.IsPresent
        Required       = $Required.IsPresent
    }
}

function New-PodeWebSelect {
    [CmdletBinding(DefaultParameterSetName = 'Options')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(ParameterSetName = 'Options')]
        [string[]]
        $Options,

        [Parameter(ParameterSetName = 'Options')]
        [string[]]
        $DisplayOptions,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $SelectedValue,

        [Parameter()]
        [int]
        $Size = 4,

        [switch]
        $Multiple,

        [switch]
        $Required,

        [switch]
        $Disabled
    )

    if (!$Multiple.IsPresent -and $SelectedValue.Length -ge 2) {
        throw 'Multiple selected values require -Multiple switch'
    }

    $Id = Get-PodeWebElementId -Tag Select -Id $Id -Name $Name

    if ($Size -le 0) {
        $Size = 4
    }

    $element = @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Select'
        Name             = $Name
        DisplayName      = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID               = $Id
        Options          = @($Options)
        DisplayOptions   = @(Protect-PodeWebValues -Value $DisplayOptions -Default $Options -EqualCount -Encode)
        IsDynamic        = ($null -ne $ScriptBlock)
        SelectedValue    = $SelectedValue
        Multiple         = $Multiple.IsPresent
        Size             = $Size
        NoAuthentication = $NoAuthentication.IsPresent
        Required         = $Required.IsPresent
        Disabled         = $Disabled.IsPresent
    }

    $routePath = "/pode.web-dynamic/elements/select/$($Id)"
    if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = @(Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data)

            $wrapped = $null
            if (Test-PodeWebActionsAsync) {
                if ($result.Length -gt 0) {
                    if ($null -eq $result[0]) {
                        $result = @()
                    }

                    $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
                }
            }
            else {
                if ($null -eq $result) {
                    $result = @()
                }

                $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
            }

            if ($result.Length -gt 0) {
                $result = ($result | Update-PodeWebSelect -Id $ElementData.ID)
            }

            $result = Join-PodeWebDynamicOutput -Wrapped $wrapped -Output $result

            if (($null -ne $result) -and ($result.Length -gt 0)) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    return $element
}

function New-PodeWebRange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [int]
        $Value = 0,

        [Parameter()]
        [int]
        $Min = 0,

        [Parameter()]
        [int]
        $Max = 100,

        [switch]
        $Disabled,

        [switch]
        $ShowValue,

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag Range -Id $Id -Name $Name

    if ($Value -lt $Min) {
        $Value = $Min
    }

    if ($Value -gt $Max) {
        $Value = $Max
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Range'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        Value         = $Value
        Min           = $Min
        Max           = $Max
        Disabled      = $Disabled.IsPresent
        ShowValue     = $ShowValue.IsPresent
        Required      = $Required.IsPresent
    }
}

function New-PodeWebProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [int]
        $Value = 0,

        [Parameter()]
        [int]
        $Min = 0,

        [Parameter()]
        [int]
        $Max = 100,

        [Parameter()]
        [ValidateSet('Blue', 'Grey', 'Green', 'Red', 'Yellow', 'Cyan', 'Light', 'Dark')]
        [string]
        $Colour = 'Blue',

        [switch]
        $ShowValue,

        [switch]
        $Striped,

        [switch]
        $Animated,

        [switch]
        $HideName
    )

    $Id = Get-PodeWebElementId -Tag Progress -Id $Id -Name $Name
    $colourType = Convert-PodeWebColourToClass -Colour $Colour

    if ($Value -lt $Min) {
        $Value = $Min
    }

    if ($Value -gt $Max) {
        $Value = $Max
    }

    $percentage = 0
    if ($Value -gt 0) {
        $percentage = ($Value / $Max) * 100.0
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Progress'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        Value         = $Value
        Min           = $Min
        Max           = $Max
        Percentage    = $percentage
        ShowValue     = $ShowValue.IsPresent
        Striped       = ($Striped.IsPresent -or $Animated.IsPresent)
        Animated      = $Animated.IsPresent
        Colour        = $Colour
        ColourType    = $ColourType
        HideName      = $HideName.IsPresent
    }
}

function New-PodeWebImage {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Source,

        [Parameter()]
        [Alias('Alt')]
        [string]
        $Title,

        [Parameter()]
        [ValidateSet('Left', 'Right', 'Center')]
        [string]
        $Alignment = 'Left',

        [Parameter()]
        [string]
        $Height = 0,

        [Parameter()]
        [string]
        $Width = 0
    )

    $Id = Get-PodeWebElementId -Tag Img -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Image'
        ID            = $Id
        Source        = (Add-PodeWebAppPath -Url $Source)
        Title         = $Title
        Alignment     = $Alignment.ToLowerInvariant()
        Height        = (ConvertTo-PodeWebSize -Value $Height -Default 'auto' -Type 'px')
        Width         = (ConvertTo-PodeWebSize -Value $Width -Default 'auto' -Type 'px')
    }
}

function New-PodeWebHeader {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet(1, 2, 3, 4, 5, 6)]
        [int]
        $Size,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secondary,

        [Parameter()]
        [object]
        $Icon
    )

    $Id = Get-PodeWebElementId -Tag Header -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Header'
        ID            = $Id
        Size          = $Size
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        Secondary     = [System.Net.WebUtility]::HtmlEncode($Secondary)
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'Header')
        NoEvents      = $true
    }
}

function New-PodeWebQuote {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [ValidateSet('Left', 'Right', 'Center')]
        [string]
        $Alignment,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Source
    )

    $Id = Get-PodeWebElementId -Tag Quote -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Quote'
        ID            = $Id
        Alignment     = $Alignment.ToLowerInvariant()
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        Source        = [System.Net.WebUtility]::HtmlEncode($Source)
        NoEvents      = $true
    }
}

function New-PodeWebList {
    [CmdletBinding(DefaultParameterSetName = 'Values')]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'Items')]
        [hashtable[]]
        $Items,

        [Parameter(Mandatory = $true, ParameterSetName = 'Values')]
        [string[]]
        $Values,

        [switch]
        $Numbered
    )

    if (!(Test-PodeWebContent -Content $Items -ComponentType Element -ObjectType ListItem)) {
        throw 'Lists can only contain ListItem elements, or raw Values'
    }

    $Id = Get-PodeWebElementId -Tag List -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'List'
        ID            = $Id
        Values        = @(foreach ($value in $Values) {
                [System.Net.WebUtility]::HtmlEncode($value)
            })
        Items         = $Items
        Numbered      = $Numbered.IsPresent
        NoEvents      = $true
    }
}

function New-PodeWebListItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A ListItem can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'List-Item'
        ID            = (Get-PodeWebElementId -Tag ListItem)
        Content       = $Content
        NoEvents      = $true
    }
}

function New-PodeWebLink {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Source,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [switch]
        $NewTab
    )

    $Id = Get-PodeWebElementId -Tag A -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Link'
        ID            = $Id
        Source        = (Add-PodeWebAppPath -Url $Source)
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        NewTab        = $NewTab.IsPresent
    }
}

function New-PodeWebText {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [ValidateSet('Normal', 'Underlined', 'StrikeThrough', 'Deleted', 'Inserted', 'Italics', 'Bold', 'Small')]
        [string]
        $Style = 'Normal',

        [Parameter(ParameterSetName = 'Paragraph')]
        [ValidateSet('Left', 'Right', 'Center')]
        [string]
        $Alignment = 'Left',

        [Parameter()]
        [string]
        $Pronunciation,

        [Parameter(ParameterSetName = 'Paragraph')]
        [switch]
        $InParagraph
    )

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Text'
        ID            = (Get-PodeWebElementId -Tag Txt -Id $Id)
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        Pronunciation = [System.Net.WebUtility]::HtmlEncode($Pronunciation)
        Style         = $Style
        InParagraph   = $InParagraph.IsPresent
        Alignment     = $Alignment.ToLowerInvariant()
        NoEvents      = $true
    }
}

function New-PodeWebLine {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id
    )

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Line'
        ID            = (Get-PodeWebElementId -Tag Line -Id $Id)
        NoEvents      = $true
    }
}

function New-PodeWebHidden {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Value
    )

    $Id = Get-PodeWebElementId -Tag Hidden -Id $Id -Name $Name

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Hidden'
        Name          = $Name
        ID            = $Id
        Value         = $Value
        NoEvents      = $true
    }
}

function New-PodeWebCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $HelpText,

        [Parameter()]
        [string]
        $DisplayUsername,

        [Parameter()]
        [string]
        $DisplayPassword,

        [Parameter()]
        [ValidateSet('Username', 'Password')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Type = @('Username', 'Password'),

        [switch]
        $ReadOnly,

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag Cred -Id $Id -Name $Name

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Credential'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        HelpText      = [System.Net.WebUtility]::HtmlEncode($HelpText)
        ReadOnly      = $ReadOnly.IsPresent
        Placeholders  = @{
            Username = (Protect-PodeWebValue -Value $DisplayUsername -Default 'Username' -Encode)
            Password = (Protect-PodeWebValue -Value $DisplayPassword -Default 'Password' -Encode)
        }
        Type          = @($Type)
        Required      = $Required.IsPresent
    }
}

function New-PodeWebDateTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $HelpText,

        [Parameter()]
        [string]
        $DisplayDate,

        [Parameter()]
        [string]
        $DisplayTime,

        [Parameter()]
        [ValidateSet('Date', 'Time')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Type = @('Date', 'Time'),

        [Parameter()]
        [string]
        $DateValue,

        [Parameter()]
        [string]
        $TimeValue,

        [switch]
        $ReadOnly,

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag DateTime -Id $Id -Name $Name

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'DateTime'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        HelpText      = [System.Net.WebUtility]::HtmlEncode($HelpText)
        ReadOnly      = $ReadOnly.IsPresent
        Placeholders  = @{
            Date = (Protect-PodeWebValue -Value $DisplayDate -Default 'Date' -Encode)
            Time = (Protect-PodeWebValue -Value $DisplayTime -Default 'Time' -Encode)
        }
        Type          = @($Type)
        Required      = $Required.IsPresent
        Values        = @{
            Date = (Protect-PodeWebValue -Value $DateValue -Default '' -Encode)
            Time = (Protect-PodeWebValue -Value $TimeValue -Default '' -Encode)
        }
    }
}

function New-PodeWebMinMax {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $HelpText,

        [Parameter()]
        [double]
        $MinValue = 0,

        [Parameter()]
        [double]
        $MaxValue = 0,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $PrependText,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $PrependIcon,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $AppendText,

        [Parameter(ParameterSetName = 'Single')]
        [string]
        $AppendIcon,

        [Parameter()]
        [string]
        $DisplayMin,

        [Parameter()]
        [string]
        $DisplayMax,

        [Parameter()]
        [ValidateSet('Min', 'Max')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Type = @('Min', 'Max'),

        [switch]
        $ReadOnly,

        [switch]
        $Required
    )

    $Id = Get-PodeWebElementId -Tag MinMax -Id $Id -Name $Name

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'MinMax'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        Values        = @{
            Min = $MinValue
            Max = $MaxValue
        }
        HelpText      = [System.Net.WebUtility]::HtmlEncode($HelpText)
        ReadOnly      = $ReadOnly.IsPresent
        Prepend       = @{
            Enabled = (![string]::IsNullOrWhiteSpace($PrependText) -or ![string]::IsNullOrWhiteSpace($PrependIcon))
            Text    = $PrependText
            Icon    = $PrependIcon
        }
        Append        = @{
            Enabled = (![string]::IsNullOrWhiteSpace($AppendText) -or ![string]::IsNullOrWhiteSpace($AppendIcon))
            Text    = $AppendText
            Icon    = $AppendIcon
        }
        Placeholders  = @{
            Min = (Protect-PodeWebValue -Value $DisplayMin -Default 'Minimum' -Encode)
            Max = (Protect-PodeWebValue -Value $DisplayMax -Default 'Maximum' -Encode)
        }
        Type          = @($Type)
        Required      = $Required.IsPresent
    }
}

function New-PodeWebRaw {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Value
    )

    $Id = Get-PodeWebElementId -Tag Raw -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Raw'
        ID            = $Id
        Value         = $Value
        NoEvents      = $true
    }
}

function New-PodeWebButtonGroup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [ValidateSet('Horizontal', 'Vertical')]
        [string]
        $Direction = 'Horizontal',

        [Parameter()]
        [ValidateSet('Normal', 'Small', 'Large')]
        [string]
        $Size = 'Normal',

        [Parameter()]
        [hashtable[]]
        $Buttons
    )

    if (!(Test-PodeWebContent -Content $Buttons -ComponentType Element -ObjectType Button)) {
        throw 'A Button Group can only contain Buttons'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Button-Group'
        ID            = (Get-PodeWebElementId -Tag ButtonGroup -Id $Id)
        Buttons       = $Buttons
        Direction     = $Direction
        SizeType      = (Convert-PodeWebButtonSizeToClass -Size $Size -Group)
        NoEvents      = $true
    }
}

function New-PodeWebButton {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [string]
        $DataValue,

        [Parameter()]
        [object]
        $Icon,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Url')]
        [string]
        $Url,

        [Parameter()]
        [ValidateSet('Blue', 'Grey', 'Green', 'Red', 'Yellow', 'Cyan', 'Light', 'Dark')]
        [string]
        $Colour = 'Blue',

        [Parameter()]
        [ValidateSet('Normal', 'Small', 'Large')]
        [string]
        $Size = 'Normal',

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [switch]
        $IconOnly,

        [switch]
        $NewLine,

        [Parameter(ParameterSetName = 'Url')]
        [switch]
        $NewTab,

        [switch]
        $Outline,

        [switch]
        $Disabled,

        [switch]
        $FullWidth
    )

    $Id = Get-PodeWebElementId -Tag Btn -Id $Id -Name $Name

    $colourType = Convert-PodeWebColourToClass -Colour $Colour
    $sizeType = Convert-PodeWebButtonSizeToClass -Size $Size -FullWidth:$FullWidth

    $element = @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Button'
        Name             = $Name
        DisplayName      = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID               = $Id
        DataValue        = $DataValue
        Icon             = (Protect-PodeWebIconType -Icon $Icon -Element 'Button')
        Url              = (Add-PodeWebAppPath -Url $Url)
        IsDynamic        = ($null -ne $ScriptBlock)
        IconOnly         = $IconOnly.IsPresent
        Colour           = $Colour
        ColourType       = $ColourType
        Outline          = $Outline.IsPresent
        SizeType         = $sizeType
        NewLine          = $NewLine.IsPresent
        NewTab           = $NewTab.IsPresent
        NoEvents         = $true
        NoAuthentication = $NoAuthentication.IsPresent
        Disabled         = $Disabled.IsPresent
    }

    $routePath = "/pode.web-dynamic/elements/button/$($Id)"
    if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

            if (($null -ne $result) -and !$WebEvent.Response.Headers.ContainsKey('Content-Disposition')) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    return $element
}

function New-PodeWebAlert {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [ValidateSet('Note', 'Tip', 'Important', 'Info', 'Warning', 'Error', 'Success')]
        [string]
        $Type = 'Note',

        [Parameter(Mandatory = $true, ParameterSetName = 'Value')]
        [string]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [hashtable[]]
        $Content
    )

    # ensure content are correct
    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'An Alert can only contain other elements'
    }

    $Id = Get-PodeWebElementId -Tag Alert -Id $Id
    $classType = Convert-PodeWebAlertTypeToClass -Type $Type
    $iconType = Convert-PodeWebAlertTypeToIcon -Type $Type

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Alert'
        ID            = $Id
        Type          = [System.Net.WebUtility]::HtmlEncode($Type)
        ClassType     = $classType
        IconType      = $iconType
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
        Content       = $Content
    }
}

function New-PodeWebIcon {
    [CmdletBinding(DefaultParameterSetName = 'Rotate')]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Colour = '',

        [Parameter()]
        [string]
        $Title = '',

        [Parameter(ParameterSetName = 'Flip')]
        [ValidateSet('Horizontal', 'Vertical')]
        [string]
        $Flip,

        [Parameter(ParameterSetName = 'Rotate')]
        [ValidateSet(0, 45, 90, 135, 180, 225, 270, 315)]
        [int]
        $Rotate = 0,

        [Parameter()]
        [ValidateSet(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50)]
        [int]
        $Size = 0,

        [Parameter()]
        [hashtable]
        $ToggleIcon,

        [Parameter()]
        [hashtable]
        $HoverIcon,

        [switch]
        $Spin
    )

    # ensure icon presets are correct
    if (!(Test-PodeWebContent -Content $ToggleIcon -ComponentType Element -ObjectType 'Icon-Preset')) {
        throw 'The ToggleIcon for an Icon can only be an Icon-Preset element'
    }

    if (!(Test-PodeWebContent -Content $HoverIcon -ComponentType Element -ObjectType 'Icon-Preset')) {
        throw 'The HoverIcon for an Icon can only be an Icon-Preset element'
    }

    # generate an ID
    $Id = Get-PodeWebElementId -Tag Icon -Id $Id

    if (![string]::IsNullOrWhiteSpace($Colour)) {
        $Colour = $Colour.ToLowerInvariant()
    }

    $element = @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Icon'
        ID            = $Id
        Name          = $Name
        Colour        = $Colour
        Title         = $Title
        Flip          = $Flip
        Rotate        = $Rotate
        Size          = $Size
        Spin          = $Spin.IsPresent
    }

    $element.Icons = @{
        Toggle = (Protect-PodeWebIconPreset -Icon $element -Preset $ToggleIcon)
        Hover  = (Protect-PodeWebIconPreset -Icon $element -Preset $HoverIcon)
    }

    return $element
}

function New-PodeWebIconPreset {
    [CmdletBinding(DefaultParameterSetName = 'Rotate')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Colour,

        [Parameter()]
        [string]
        $Title,

        [Parameter(ParameterSetName = 'Flip')]
        [ValidateSet('Horizontal', 'Vertical')]
        [string]
        $Flip,

        [Parameter(ParameterSetName = 'Rotate')]
        [ValidateSet(-1, 0, 45, 90, 135, 180, 225, 270, 315)]
        [int]
        $Rotate = -1,

        [Parameter()]
        [ValidateSet(-1, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50)]
        [int]
        $Size = -1,

        [switch]
        $Spin
    )

    if (![string]::IsNullOrWhiteSpace($Colour)) {
        $Colour = $Colour.ToLowerInvariant()
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Icon-Preset'
        Name          = $Name
        Colour        = $Colour
        Title         = $Title
        Flip          = $Flip
        Rotate        = $Rotate
        Size          = $Size
        Spin          = (Test-PodeWebParameter -Parameters $PSBoundParameters -Name 'Spin' -Value $Spin.IsPresent)
    }
}

function New-PodeWebSpinner {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Colour,

        [Parameter()]
        [string]
        $Title
    )

    if (![string]::IsNullOrWhiteSpace($Colour)) {
        $Colour = $Colour.ToLowerInvariant()
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Spinner'
        ID            = (Get-PodeWebElementId -Tag Spinner -Id $Id)
        Colour        = $Colour
        Title         = $Title
        NoEvents      = $true
    }
}

function New-PodeWebBadge {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [ValidateSet('Blue', 'Grey', 'Green', 'Red', 'Yellow', 'Cyan', 'Light', 'Dark')]
        [string]
        $Colour = 'Blue',

        [Parameter(Mandatory = $true)]
        [string]
        $Value
    )

    $Id = Get-PodeWebElementId -Tag Alert -Id $Id
    $colourType = Convert-PodeWebColourToClass -Colour $Colour

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Badge'
        ID            = $Id
        Colour        = $Colour
        ColourType    = $ColourType.ToLowerInvariant()
        Value         = [System.Net.WebUtility]::HtmlEncode($Value)
    }
}

function New-PodeWebComment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $AvatarUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [Parameter()]
        [DateTime]
        $TimeStamp
    )

    $Id = Get-PodeWebElementId -Tag Comment -Id $Id

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Comment'
        ID            = $Id
        AvatarUrl     = (Add-PodeWebAppPath -Url $AvatarUrl)
        Username      = [System.Net.WebUtility]::HtmlEncode($Username)
        Message       = [System.Net.WebUtility]::HtmlEncode($Message)
        TimeStamp     = $TimeStamp
        NoEvents      = $true
    }
}

function New-PodeWebChart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Message,

        [Parameter(ParameterSetName = 'Data', ValueFromPipeline = $true)]
        $Data,

        [Parameter(Mandatory = $true, ParameterSetName = 'Dynamic')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [ValidateSet('line', 'pie', 'doughnut', 'bar')]
        [string]
        $Type = 'line',

        [Parameter()]
        [int]
        $MaxItems = 0,

        [Parameter()]
        [string]
        $Height = 0,

        [Parameter(ParameterSetName = 'Dynamic')]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [int]
        $MinX = [int]::MinValue,

        [Parameter()]
        [int]
        $MaxX = [int]::MaxValue,

        [Parameter()]
        [int]
        $MinY = [int]::MinValue,

        [Parameter()]
        [int]
        $MaxY = [int]::MaxValue,

        [Parameter(ParameterSetName = 'Dynamic')]
        [int]
        $RefreshInterval = 60,

        [Parameter()]
        [string[]]
        $Colours,

        [switch]
        $Append,

        [switch]
        $TimeLabels,

        [Parameter(ParameterSetName = 'Dynamic')]
        [switch]
        $AutoRefresh,

        [Parameter(ParameterSetName = 'Dynamic')]
        [switch]
        $NoRefresh,

        [switch]
        $NoLegend,

        [switch]
        $AsCard
    )

    begin {
        $items = @()
    }

    process {
        if ($null -ne $Data) {
            if ($Data.Values -isnot [array]) {
                if ($Data.Values -is [hashtable]) {
                    $Data.Values = @($Data.Values)
                }
                else {
                    $Data.Values = @(@{
                            Key   = 'Default'
                            Value = $Data.Values
                        })
                }
            }

            $items += $Data
        }
    }

    end {
        $Id = Get-PodeWebElementId -Tag Chart -Id $Id -Name $Name

        if ($MaxItems -lt 0) {
            $MaxItems = 0
        }

        if ($RefreshInterval -le 0) {
            $RefreshInterval = 60
        }

        if (($null -ne $Colours) -and ($Colours.Length -gt 0)) {
            foreach ($clr in $Colours) {
                if ($clr -inotmatch '^\s*#(([a-f\d])([a-f\d])([a-f\d])){1,2}\s*$') {
                    throw "Invalid colour supplied, should be hex format: $($clr)"
                }
            }
        }

        $element = @{
            Operation        = 'New'
            ComponentType    = 'Element'
            ObjectType       = 'Chart'
            Name             = $Name
            DisplayName      = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
            ID               = $Id
            Message          = $Message
            ChartType        = $Type
            IsDynamic        = ($null -ne $ScriptBlock)
            Append           = $Append.IsPresent
            MaxItems         = $MaxItems
            Height           = (ConvertTo-PodeWebSize -Value $Height -Default 'auto' -Type 'px')
            TimeLabels       = $TimeLabels.IsPresent
            AutoRefresh      = $AutoRefresh.IsPresent
            RefreshInterval  = ($RefreshInterval * 1000)
            NoRefresh        = $NoRefresh.IsPresent
            NoLegend         = $NoLegend.IsPresent
            Min              = @{
                X = $MinX
                Y = $MinY
            }
            Max              = @{
                X = $MaxX
                Y = $MaxY
            }
            NoEvents         = $true
            NoAuthentication = $NoAuthentication.IsPresent
            Colours          = $Colours
        }

        $routePath = "/pode.web-dynamic/elements/chart/$($Id)"
        if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
            # check for scoped vars
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
            $elementLogic = @{
                ScriptBlock    = $ScriptBlock
                UsingVariables = $usingVars
            }

            $auth = $null
            if (!$NoAuthentication -and !$PageData.NoAuthentication) {
                $auth = (Get-PodeWebState -Name 'auth')
            }

            if (Test-PodeIsEmpty $EndpointName) {
                $EndpointName = Get-PodeWebState -Name 'endpoint-name'
            }

            $argList = @(
                @{ Data = $ArgumentList },
                $element,
                $ElementData,
                $elementLogic
            )

            Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
                param($Data, $Element, $Parent, $Logic)
                $global:ElementData = $Element
                $global:ParentData = $Parent
                Set-PodeWebMetadata

                $result = @(Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data)

                $wrapped = $null
                if (Test-PodeWebActionsAsync) {
                    if ($result.Length -gt 0) {
                        if ($null -eq $result[0]) {
                            $result = @()
                        }

                        $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
                    }
                }
                else {
                    if ($null -eq $result) {
                        $result = @()
                    }

                    $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
                }

                if ($result.Length -gt 0) {
                    $result = ($result | Update-PodeWebChart -Id $ElementData.ID)
                }

                $result = Join-PodeWebDynamicOutput -Wrapped $wrapped -Output $result

                if (($null -ne $result) -and ($result.Length -gt 0)) {
                    Write-PodeJsonResponse -Value $result
                }

                $global:ElementData = $null
                $global:ParentData = $null
            }
        }

        $element['Data'] = $items

        if ($AsCard) {
            $element = New-PodeWebCard -Name $Name -DisplayName $DisplayName -Content $element
        }

        return $element
    }
}

function New-PodeWebCounterChart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Counter,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [int]
        $MaxItems = 30,

        [Parameter()]
        [int]
        $MinX = [int]::MinValue,

        [Parameter()]
        [int]
        $MaxX = [int]::MaxValue,

        [Parameter()]
        [int]
        $MinY = [int]::MinValue,

        [Parameter()]
        [int]
        $MaxY = [int]::MaxValue,

        [Parameter()]
        [string[]]
        $Colours,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [switch]
        $NoLegend,

        [switch]
        $AsCard
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Split-Path -Path $Counter -Leaf
    }

    if ($MaxItems -le 0) {
        $MaxItems = 30
    }

    New-PodeWebChart `
        -Name $Name `
        -DisplayName $DisplayName `
        -Type Line `
        -MaxItems $MaxItems `
        -ArgumentList $Counter `
        -Append `
        -TimeLabels `
        -AutoRefresh `
        -MinX $MinX `
        -MinY $MinY `
        -MaxX $MaxX `
        -MaxY $MaxY `
        -Colours $Colours `
        -NoAuthentication:$NoAuthentication `
        -AsCard:$AsCard `
        -NoLegend:$NoLegend `
        -ScriptBlock {
        param($counter)
        @{
            Values = ((Get-Counter -Counter $counter -SampleInterval 1 -MaxSamples 2).CounterSamples.CookedValue | Measure-Object -Average).Average
        }
    }
}

function New-PodeWebTable {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Message,

        [Parameter()]
        [string]
        $DataColumn,

        [Parameter()]
        [hashtable[]]
        $Columns,

        [Parameter(ParameterSetName = 'Data', ValueFromPipeline = $true)]
        $Data,

        [Parameter(ParameterSetName = 'Dynamic')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'Dynamic')]
        [object[]]
        $ArgumentList,

        [Parameter(ParameterSetName = 'Csv')]
        [string]
        $CsvFilePath,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [Alias('PageAmount')]
        [int]
        $PageSize = 20,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [scriptblock]
        $ClickScriptBlock,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [int]
        $RefreshInterval = 60,

        [switch]
        $Compact,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [switch]
        $Filter,

        [switch]
        $SimpleFilter,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [switch]
        $Sort,

        [switch]
        $SimpleSort,

        [switch]
        $Click,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [switch]
        $Paginate,

        [switch]
        $NoExport,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [switch]
        $NoRefresh,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Csv')]
        [switch]
        $AutoRefresh,

        [switch]
        $AsCard
    )

    begin {
        $items = @()
    }

    process {
        if ($null -ne $Data) {
            $items += $Data
        }
    }

    end {
        $Id = Get-PodeWebElementId -Tag Table -Id $Id -Name $Name

        if (![string]::IsNullOrWhiteSpace($CsvFilePath) -and $CsvFilePath.StartsWith('.')) {
            $CsvFilePath = Join-PodeWebPath (Get-PodeServerPath) $CsvFilePath
        }

        if ($RefreshInterval -le 0) {
            $RefreshInterval = 60
        }

        $element = @{
            Operation        = 'New'
            ComponentType    = 'Element'
            ObjectType       = 'Table'
            Name             = $Name
            DisplayName      = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
            ID               = $Id
            DataColumn       = $DataColumn
            Columns          = $Columns
            Buttons          = @()
            Message          = $Message
            Compact          = $Compact.IsPresent
            Filter           = @{
                Enabled = ($Filter.IsPresent -or $SimpleFilter.IsPresent)
                Simple  = $SimpleFilter.IsPresent
            }
            Sort             = @{
                Enabled = ($Sort.IsPresent -or $SimpleSort.IsPresent)
                Simple  = $SimpleSort.IsPresent
            }
            Click            = ($Click.IsPresent -or ($null -ne $ClickScriptBlock))
            ClickIsDynamic   = ($null -ne $ClickScriptBlock)
            IsDynamic        = ($PSCmdlet.ParameterSetName -iin @('dynamic', 'csv'))
            NoExport         = $NoExport.IsPresent
            AutoRefresh      = $AutoRefresh.IsPresent
            RefreshInterval  = ($RefreshInterval * 1000)
            NoRefresh        = $NoRefresh.IsPresent
            NoAuthentication = $NoAuthentication.IsPresent
            Paging           = @{
                Enabled = $Paginate.IsPresent
                Size    = $PageSize
            }
            NoEvents         = $true
        }

        # auth an endpoint
        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        # main table data script
        $routePath = "/pode.web-dynamic/elements/table/$($Id)"
        $buildRoute = (($null -ne $ScriptBlock) -or ![string]::IsNullOrWhiteSpace($CsvFilePath))

        if ($buildRoute -and !(Test-PodeWebRoute -Path $routePath)) {
            # check for scoped vars
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
            $elementLogic = @{
                ScriptBlock    = $ScriptBlock
                UsingVariables = $usingVars
            }

            $argList = @(
                @{
                    Data    = $ArgumentList
                    CsvPath = $CsvFilePath
                },
                $element,
                $ElementData,
                $elementLogic
            )

            Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
                param($Data, $Element, $Parent, $Logic)
                $global:ElementData = $Element
                $global:ParentData = $Parent
                Set-PodeWebMetadata

                $csvFilePath = $Data.CsvPath
                if ([string]::IsNullOrWhiteSpace($csvFilePath)) {
                    $result = @(Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data)
                }
                else {
                    $result = Import-Csv -Path $csvFilePath

                    $filter = $WebEvent.Data['Filter']
                    if (![string]::IsNullOrWhiteSpace($filter)) {
                        $filter = "*$($filter)*"
                        $result = @($result | Where-Object { ($_.psobject.properties.value -ilike $filter).length -gt 0 })
                    }
                }

                $wrapped = $null
                if (Test-PodeWebActionsAsync) {
                    if ($result.Length -gt 0) {
                        if ($null -eq $result[0]) {
                            $result = @()
                        }

                        $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
                    }
                }
                else {
                    if ($null -eq $result) {
                        $result = @()
                    }

                    $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
                }

                if ($result.Length -gt 0) {
                    $paginate = $ElementData.Paging.Enabled
                    $result = ($result | Update-PodeWebTable -Id $ElementData.ID -Columns $ElementData.Columns -Paginate:$paginate)
                }

                $result = Join-PodeWebDynamicOutput -Wrapped $wrapped -Output $result

                if (($null -ne $result) -and ($result.Length -gt 0)) {
                    Write-PodeJsonResponse -Value $result
                }

                $global:ElementData = $null
                $global:ParentData = $null
            }
        }

        # table row click
        $clickPath = "$($routePath)/click"
        if (($null -ne $ClickScriptBlock) -and !(Test-PodeWebRoute -Path $clickPath)) {
            # check for scoped vars
            $ClickScriptBlock, $clickUsingVars = Convert-PodeScopedVariables -ScriptBlock $ClickScriptBlock -PSSession $PSCmdlet.SessionState
            $clickLogic = @{
                ScriptBlock    = $ClickScriptBlock
                UsingVariables = $clickUsingVars
            }

            $argList = @(
                @{ Data = $ArgumentList },
                $element,
                $ElementData,
                $clickLogic
            )

            Add-PodeRoute -Method Post -Path $clickPath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
                param($Data, $Element, $Parent, $Logic)
                $global:ElementData = $Element
                $global:ParentData = $Parent
                Set-PodeWebMetadata

                $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

                if (($null -ne $result) -and !$WebEvent.Response.Headers.ContainsKey('Content-Disposition')) {
                    Write-PodeJsonResponse -Value $result
                }

                $global:ElementData = $null
                $global:ParentData = $null
            }
        }

        $element['Data'] = $items

        if ($AsCard) {
            $element = New-PodeWebCard -Name $Name -DisplayName $DisplayName -Content $element
        }

        return $element
    }
}

function Initialize-PodeWebTableColumn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Width = 0,

        [Parameter()]
        [ValidateSet('Left', 'Right', 'Center')]
        [string]
        $Alignment = 'Left',

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [object]
        $Icon,

        [Parameter()]
        [string]
        $Default,

        [switch]
        $Hide
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = $Key
    }

    return @{
        Key       = $Key
        Width     = (ConvertTo-PodeWebSize -Value $Width -Default 'auto' -Type '%')
        Alignment = $Alignment.ToLowerInvariant()
        Name      = $Name
        Icon      = (Protect-PodeWebIconType -Icon $Icon -Element 'Table Column')
        Default   = $Default
        Hide      = $Hide.IsPresent
    }
}

function Add-PodeWebTableButton {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Table,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [object]
        $Icon,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [switch]
        $WithText
    )

    if ($Table.ObjectType -ieq 'card') {
        $Table = @($Table.Content | Where-Object { $_.ObjectType -ieq 'table' })[0]
    }

    $routePath = "/pode.web-dynamic/elements/table/$($Table.ID)/button/$($Name)"
    if (!(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$Table.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $Table,
            $ElementData,
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

            if (($null -ne $result) -and !$WebEvent.Response.Headers.ContainsKey('Content-Disposition')) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    $Table.Buttons += @{
        Name        = $Name
        DisplayName = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        Icon        = (Protect-PodeWebIconType -Icon $Icon -Element 'Table Button')
        IsDynamic   = ($null -ne $ScriptBlock)
        WithText    = $WithText.IsPresent
    }
}

function New-PodeWebCodeEditor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Language = 'plaintext',

        [Parameter()]
        [ValidateSet('', 'vs', 'vs-dark', 'hc-black')]
        [string]
        $Theme,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [scriptblock]
        $Upload,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [switch]
        $ReadOnly,

        [switch]
        $AsCard
    )

    $Id = Get-PodeWebElementId -Tag CodeEditor -Id $Id -Name $Name
    $uploadable = ($null -ne $Upload)

    $element = @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Code-Editor'
        Name             = $Name
        ID               = $Id
        Language         = $Language.ToLowerInvariant()
        Theme            = $Theme
        Value            = $Value
        ReadOnly         = $ReadOnly.IsPresent
        Uploadable       = $uploadable
        NoAuthentication = $NoAuthentication.IsPresent
    }

    # upload route
    $routePath = "/pode.web-dynamic/elements/code-editor/$($Id)/upload"
    if ($uploadable -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $Upload, $uploadUsingVars = Convert-PodeScopedVariables -ScriptBlock $Upload -PSSession $PSCmdlet.SessionState
        $uploadLogic = @{
            ScriptBlock    = $Upload
            UsingVariables = $uploadUsingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $uploadLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data
            if ($null -ne $result) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    if ($AsCard) {
        $element = New-PodeWebCard -Name $Name -Content $element
    }

    return $element
}

function New-PodeWebForm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Message,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [ValidateSet('Get', 'Post')]
        [string]
        $Method = 'Post',

        [Parameter()]
        [string]
        $Action,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SubmitText = 'Submit',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResetText = 'Reset',

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [switch]
        $AsCard,

        [switch]
        $ShowReset
    )

    # ensure content are correct
    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Form can only contain other elements'
    }

    # generate ID
    $Id = Get-PodeWebElementId -Tag Form -Id $Id -Name $Name
    $routePath = "/pode.web-dynamic/elements/form/$($Id)"

    $element = @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Form'
        Name             = $Name
        ID               = $Id
        Message          = $Message
        Content          = $Content
        NoHeader         = $NoHeader.IsPresent
        Method           = $Method
        Action           = (Protect-PodeWebValue -Value $Action -Default $routePath)
        NoEvents         = $true
        NoAuthentication = $NoAuthentication.IsPresent
        ShowReset        = $ShowReset.IsPresent
        ResetText        = (Protect-PodeWebValue -Value $ResetText -Default 'Reset' -Encode)
        SubmitText       = (Protect-PodeWebValue -Value $SubmitText -Default 'Submit' -Encode)
    }

    if (!(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data
            if ($null -ne $result) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    if ($AsCard) {
        $element = New-PodeWebCard -Name $Name -Content $element
    }

    return $element
}

function New-PodeWebTimer {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [int]
        $Interval = 60,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication
    )

    # generate timer id
    $Id = Get-PodeWebElementId -Tag Timer -Id $Id -Name $Name

    # check for min interval
    if ($Interval -lt 10) {
        $Interval = 10
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    $element = @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Timer'
        Name             = $Name
        ID               = $Id
        Interval         = ($Interval * 1000)
        NoEvents         = $true
        NoAuthentication = $NoAuthentication.IsPresent
    }

    $elementLogic = @{
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
    }

    $routePath = "/pode.web-dynamic/elements/timer/$($Id)"
    if (!(Test-PodeWebRoute -Path $routePath)) {
        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data
            if ($null -ne $result) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    $element = New-PodeWebContainer -Content $element -Hide
    return $element
}

function New-PodeWebTile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [object]
        $Icon,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [hashtable[]]
        $Content,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [scriptblock]
        $ClickScriptBlock,

        [Parameter()]
        [ValidateSet('Blue', 'Grey', 'Green', 'Red', 'Yellow', 'Cyan', 'Light', 'Dark')]
        [string]
        $Colour = 'Blue',

        [Parameter()]
        [int]
        $RefreshInterval = 60,

        [switch]
        $NoRefresh,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication,

        [Parameter()]
        [switch]
        $AutoRefresh,

        [switch]
        $NewLine
    )

    # ensure content are correct
    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Tile can only contain other elements'
    }

    $Id = Get-PodeWebElementId -Tag Tile -Id $Id -Name $Name
    $colourType = Convert-PodeWebColourToClass -Colour $Colour

    if ($RefreshInterval -le 0) {
        $RefreshInterval = 60
    }

    $element = @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Tile'
        Name             = $Name
        DisplayName      = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID               = $Id
        Click            = ($null -ne $ClickScriptBlock)
        IsDynamic        = ($null -ne $ScriptBlock)
        Content          = $Content
        Icon             = (Protect-PodeWebIconType -Icon $Icon -Element 'Tile')
        Colour           = $Colour
        ColourType       = $ColourType
        AutoRefresh      = $AutoRefresh.IsPresent
        RefreshInterval  = ($RefreshInterval * 1000)
        NoRefresh        = $NoRefresh.IsPresent
        NewLine          = $NewLine.IsPresent
        NoEvents         = $true
        NoAuthentication = $NoAuthentication.IsPresent
    }

    # auth an endpoint
    $auth = $null
    if (!$NoAuthentication -and !$PageData.NoAuthentication) {
        $auth = (Get-PodeWebState -Name 'auth')
    }

    if (Test-PodeIsEmpty $EndpointName) {
        $EndpointName = Get-PodeWebState -Name 'endpoint-name'
    }

    # main route to load tile value
    $routePath = "/pode.web-dynamic/elements/tile/$($Id)"
    if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = @(Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data)

            $wrapped = $null
            if (Test-PodeWebActionsAsync) {
                if ($result.Length -gt 0) {
                    if ($null -eq $result[0]) {
                        $result = @()
                    }

                    $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
                }
            }
            else {
                if ($null -eq $result) {
                    $result = @()
                }

                $wrapped, $result = Split-PodeWebDynamicOutput -Output $result
            }

            if ($result.Length -gt 0) {
                $result = ($result | Update-PodeWebTile -Id $ElementData.ID)
            }

            $result = Join-PodeWebDynamicOutput -Wrapped $wrapped -Output $result

            if (($null -ne $result) -and ($result.Length -gt 0)) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    # tile click route
    $clickPath = "$($routePath)/click"
    if (($null -ne $ClickScriptBlock) -and !(Test-PodeWebRoute -Path $clickPath)) {
        # check for scoped vars
        $ClickScriptBlock, $clickUsingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $clickLogic = @{
            ScriptBlock    = $ClickScriptBlock
            UsingVariables = $clickUsingVars
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $element,
            $ElementData,
            $clickLogic
        )

        Add-PodeRoute -Method Post -Path $clickPath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Element, $Parent, $Logic)
            $global:ElementData = $Element
            $global:ParentData = $Parent
            Set-PodeWebMetadata

            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

            if (($null -ne $result) -and !$WebEvent.Response.Headers.ContainsKey('Content-Disposition')) {
                Write-PodeJsonResponse -Value $result
            }

            $global:ElementData = $null
            $global:ParentData = $null
        }
    }

    return $element
}

function New-PodeWebFileStream {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter()]
        [int]
        $Height = 20,

        [Parameter()]
        [int]
        $Interval = 10,

        [Parameter()]
        [object]
        $Icon,

        [switch]
        $NoHeader
    )

    $Id = Get-PodeWebElementId -Tag FileStream -Id $Id -Name $Name

    if ($Height -le 0) {
        $Height = 20
    }

    if ($Interval -le 0) {
        $Interval = 10
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'File-Stream'
        Name          = $Name
        ID            = $Id
        Height        = $Height
        Url           = (Add-PodeWebAppPath -Url $Url)
        Interval      = ($Interval * 1000)
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'File Stream')
        NoHeader      = $NoHeader.IsPresent
    }
}

function New-PodeWebIFrame {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter()]
        [string]
        $Title
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = $Name
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'iFrame'
        Name          = $Name
        ID            = (Get-PodeWebElementId -Tag iFrame -Id $Id -Name $Name)
        Url           = (Add-PodeWebAppPath -Url $Url)
        Title         = $Title
        NoEvents      = $true
    }
}

function New-PodeWebAudio {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Source,

        [Parameter()]
        [hashtable[]]
        $Track,

        [Parameter()]
        [string]
        $NotSupportedText,

        [Parameter()]
        [string]
        $Width = 20,

        [switch]
        $Muted,

        [switch]
        $AutoPlay,

        [switch]
        $AutoBuffer,

        [switch]
        $Loop,

        [switch]
        $NoControls,

        [switch]
        $NoDownload
    )

    if (!(Test-PodeWebContent -Content $Source -ComponentType Element -ObjectType AudioSource)) {
        throw 'Audio sources can only contain AudioSource elements'
    }

    if (!(Test-PodeWebContent -Content $Track -ComponentType Element -ObjectType MediaTrack)) {
        throw 'Audio tracks can only contain MediaTrack elements'
    }

    return @{
        Operation        = 'New'
        ComponentType    = 'Element'
        ObjectType       = 'Audio'
        Name             = $Name
        ID               = (Get-PodeWebElementId -Tag Audio -Id $Id -Name $Name)
        Width            = (ConvertTo-PodeWebSize -Value $Width -Default 20 -Type '%')
        Sources          = $Source
        Tracks           = $Track
        NotSupportedText = (Protect-PodeWebValue -Value $NotSupportedText -Default 'Your browser does not support the audio element' -Encode)
        Muted            = $Muted.IsPresent
        AutoPlay         = $AutoPlay.IsPresent
        AutoBuffer       = $AutoBuffer.IsPresent
        Loop             = $Loop.IsPresent
        NoControls       = $NoControls.IsPresent
        NoDownload       = $NoDownload.IsPresent
    }
}

function New-PodeWebAudioSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    $type = [string]::Empty

    switch (($Url -split '\.')[-1].ToLowerInvariant()) {
        'mp3' { $type = 'audio/mpeg' }
        'ogg' { $type = 'audio/ogg' }
        'wav' { $type = 'audio/wav' }
        default {
            throw "Audio source type unsupported: $($_)"
        }
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'AudioSource'
        Url           = (Add-PodeWebAppPath -Url $Url)
        Type          = $type
        NoEvents      = $true
    }
}

function New-PodeWebVideo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Source,

        [Parameter()]
        [hashtable[]]
        $Track,

        [Parameter()]
        [string]
        $Thumbnail,

        [Parameter()]
        [string]
        $NotSupportedText,

        [Parameter()]
        [string]
        $Width = 20,

        [Parameter()]
        [string]
        $Height = 15,

        [switch]
        $Muted,

        [switch]
        $AutoPlay,

        [switch]
        $AutoBuffer,

        [switch]
        $Loop,

        [switch]
        $NoControls,

        [switch]
        $NoDownload,

        [switch]
        $NoPictureInPicture
    )

    if (!(Test-PodeWebContent -Content $Source -ComponentType Element -ObjectType VideoSource)) {
        throw 'Video sources can only contain VideoSource elements'
    }

    if (!(Test-PodeWebContent -Content $Track -ComponentType Element -ObjectType MediaTrack)) {
        throw 'Video tracks can only contain MediaTrack elements'
    }

    return @{
        Operation          = 'New'
        ComponentType      = 'Element'
        ObjectType         = 'Video'
        Name               = $Name
        ID                 = (Get-PodeWebElementId -Tag Video -Id $Id -Name $Name)
        Width              = (ConvertTo-PodeWebSize -Value $Width -Default 20 -Type '%')
        Height             = (ConvertTo-PodeWebSize -Value $Height -Default 15 -Type '%')
        Sources            = $Source
        Tracks             = $Track
        Thumbnail          = $Thumbnail
        NotSupportedText   = (Protect-PodeWebValue -Value $NotSupportedText -Default 'Your browser does not support the video element' -Encode)
        Muted              = $Muted.IsPresent
        AutoPlay           = $AutoPlay.IsPresent
        AutoBuffer         = $AutoBuffer.IsPresent
        Loop               = $Loop.IsPresent
        NoControls         = $NoControls.IsPresent
        NoDownload         = $NoDownload.IsPresent
        NoPictureInPicture = $NoPictureInPicture.IsPresent
    }
}

function New-PodeWebVideoSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    $type = [string]::Empty

    switch (($Url -split '\.')[-1].ToLowerInvariant()) {
        'mp4' { $type = 'video/mp4' }
        'ogg' { $type = 'video/ogg' }
        'webm' { $type = 'video/webm' }
        default {
            throw "Video source type unsupported: $($_)"
        }
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'VideoSource'
        Url           = (Add-PodeWebAppPath -Url $Url)
        Type          = $type
        NoEvents      = $true
    }
}

function New-PodeWebMediaTrack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter()]
        [string]
        $Language,

        [Parameter()]
        [string]
        $Title,

        [Parameter()]
        [ValidateSet('captions', 'chapters', 'descriptions', 'metadata', 'subtitles')]
        [string]
        $Type = 'subtitles',

        [switch]
        $Default
    )

    if (($Url -split '\.')[-1] -ine 'vtt') {
        throw 'Invalid media track file format supplied, expected a .vtt file'
    }

    if (($Type -ieq 'subtitles') -and [string]::IsNullOrWhiteSpace($Language)) {
        throw 'A language is required for subtitle tracks'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'MediaTrack'
        Url           = (Add-PodeWebAppPath -Url $Url)
        Language      = $Language
        Title         = $Title
        Type          = $Type.ToLowerInvariant()
        Default       = $Default.IsPresent
        NoEvents      = $true
    }
}

function Use-PodeWebElement {
    [CmdletBinding(DefaultParameterSetName = 'ID')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Element')]
        [hashtable]
        $Element,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ID')]
        [hashtable]
        $Id
    )

    # element is an element?
    if (($null -ne $Element) -and ($Element.ComponentType -ine 'element')) {
        throw 'You can only reference another element'
    }

    # set element ID
    if ($null -ne $Element) {
        $Id = $Element.ID
    }

    return @{
        Operation     = 'Use'
        ComponentType = 'Element'
        ObjectType    = 'Element'
        Reference     = @{
            ID = $Id
        }
    }
}

function New-PodeWebGrid {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Cells,

        [Parameter()]
        [int]
        $Width = 0,

        [switch]
        $Vertical
    )

    if (!(Test-PodeWebContent -Content $Cells -ComponentType Element -ObjectType Cell)) {
        throw 'A Grid can only contain Cell elements'
    }

    if ($Vertical) {
        $Width = 1
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Grid'
        Cells         = $Cells
        Width         = $Width
        ID            = (Get-PodeWebElementId -Tag Grid -Id $Id)
    }
}

function New-PodeWebCell {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [Parameter()]
        [string]
        $Width,

        [Parameter()]
        [ValidateSet('Left', 'Right', 'Center')]
        [string]
        $Alignment = 'Left'
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Cell can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Cell'
        Content       = $Content
        Width         = (Protect-PodeWebRange -Value $Width -Min 1 -Max 12)
        ID            = (Get-PodeWebElementId -Tag Cell -Id $Id)
        Alignment     = $Alignment.ToLowerInvariant()
    }
}

function New-PodeWebTabs {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Tabs,

        [Parameter()]
        [int]
        $CycleInterval = 15,

        [switch]
        $Cycle
    )

    if (!(Test-PodeWebContent -Content $Tabs -ComponentType Element -ObjectType Tab)) {
        throw 'Tabs can only contain Tab elements'
    }

    if ($CycleInterval -lt 10) {
        $CycleInterval = 10
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Tabs'
        ID            = (Get-PodeWebElementId -Tag Tabs -Id $Id)
        Tabs          = $Tabs
        Cycle         = @{
            Enabled  = $Cycle.IsPresent
            Interval = ($CycleInterval * 1000)
        }
    }
}

function New-PodeWebTab {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [Parameter()]
        [object]
        $Icon
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Tab can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Tab'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = (Get-PodeWebElementId -Tag Tab -Id $Id -Name $Name)
        Content       = $Content
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'Tab')
    }
}

function New-PodeWebCard {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [Parameter()]
        [hashtable[]]
        $Buttons,

        [Parameter()]
        [object]
        $Icon,

        [switch]
        $NoTitle,

        [switch]
        $NoHide
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Card can only contain other elements'
    }

    if (!(Test-PodeWebContent -Content $Buttons -ComponentType Element -ObjectType Button, 'Button-Group')) {
        throw 'Card Buttons can only contain Buttons'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Card'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = (Get-PodeWebElementId -Tag Card -Id $Id -Name $Name)
        Content       = $Content
        Buttons       = $Buttons
        NoTitle       = $NoTitle.IsPresent
        NoHide        = $NoHide.IsPresent
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'Card')
    }
}

function New-PodeWebContainer {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [switch]
        $NoBackground,

        [switch]
        $Hide
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Container can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Container'
        ID            = (Get-PodeWebElementId -Tag Container -Id $Id)
        Content       = $Content
        NoBackground  = $NoBackground.IsPresent
        Hide          = $Hide.IsPresent
    }
}

function New-PodeWebModal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [Parameter()]
        [object]
        $Icon,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SubmitText = 'Submit',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $CloseText = 'Close',

        [Parameter()]
        [ValidateSet('Small', 'Medium', 'Large')]
        [string]
        $Size = 'Small',

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [ValidateSet('Get', 'Post')]
        [string]
        $Method = 'Post',

        [Parameter()]
        [string]
        $Action,

        [switch]
        $AsForm,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Modal can only contain other elements'
    }

    # generate ID
    $Id = Get-PodeWebElementId -Tag Modal -Id $Id -Name $Name

    $routePath = "/pode.web-dynamic/elements/modal/$($Id)"
    if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Logic)
            Set-PodeWebMetadata
            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

            if ($null -ne $result) {
                Write-PodeJsonResponse -Value $result
            }
        }
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Modal'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'Modal')
        Content       = $Content
        CloseText     = [System.Net.WebUtility]::HtmlEncode($CloseText)
        SubmitText    = [System.Net.WebUtility]::HtmlEncode($SubmitText)
        Size          = $Size
        AsForm        = $AsForm.IsPresent
        ShowSubmit    = ($null -ne $ScriptBlock)
        Method        = $Method
        Action        = (Protect-PodeWebValue -Value $Action -Default $routePath)
    }
}

function New-PodeWebHero {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Title,

        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [Parameter()]
        [hashtable[]]
        $Content
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Hero can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Hero'
        ID            = (Get-PodeWebElementId -Tag Hero -Id $Id)
        Title         = [System.Net.WebUtility]::HtmlEncode($Title)
        Message       = [System.Net.WebUtility]::HtmlEncode($Message)
        Content       = $Content
    }
}

function New-PodeWebCarousel {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Slides
    )

    if (!(Test-PodeWebContent -Content $Slides -ComponentType Element -ObjectType Slide)) {
        throw 'A Carousel can only contain Slide elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Carousel'
        ID            = (Get-PodeWebElementId -Tag Carousel -Id $Id)
        Slides        = $Slides
    }
}

function New-PodeWebSlide {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Content,

        [Parameter()]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Message
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Slide can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Slide'
        Content       = $Content
        ID            = (Get-PodeWebElementId -Tag Slide)
        Title         = [System.Net.WebUtility]::HtmlEncode($Title)
        Message       = [System.Net.WebUtility]::HtmlEncode($Message)
    }
}

function New-PodeWebSteps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Steps,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication
    )

    if (!(Test-PodeWebContent -Content $Steps -ComponentType Element -ObjectType Step)) {
        throw 'Steps can only contain Step elements'
    }

    # generate ID
    $Id = Get-PodeWebElementId -Tag Steps -Id $Id -Name $Name

    # add route
    $routePath = "/pode.web-dynamic/elements/steps/$($Id)"
    if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Logic)
            Set-PodeWebMetadata
            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

            if ($null -ne $result) {
                Write-PodeJsonResponse -Value $result
            }
        }
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Steps'
        ID            = $Id
        Steps         = $Steps
    }
}

function New-PodeWebStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [hashtable[]]
        $Content,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [object]
        $Icon,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('NoAuth')]
        [switch]
        $NoAuthentication
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Step can only contain other elements'
    }

    # generate ID
    $Id = Get-PodeWebElementId -Tag Step -Name $Name

    # add route
    $routePath = "/pode.web-dynamic/elements/step/$($Id)"
    if (($null -ne $ScriptBlock) -and !(Test-PodeWebRoute -Path $routePath)) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $elementLogic = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }

        $auth = $null
        if (!$NoAuthentication -and !$PageData.NoAuthentication) {
            $auth = (Get-PodeWebState -Name 'auth')
        }

        if (Test-PodeIsEmpty $EndpointName) {
            $EndpointName = Get-PodeWebState -Name 'endpoint-name'
        }

        $argList = @(
            @{ Data = $ArgumentList },
            $elementLogic
        )

        Add-PodeRoute -Method Post -Path $routePath -Authentication $auth -ArgumentList $argList -EndpointName $EndpointName -ScriptBlock {
            param($Data, $Logic)
            Set-PodeWebMetadata
            $result = Invoke-PodeWebScriptBlock -Logic $Logic -Arguments $Data.Data

            if ($null -ne $result) {
                Write-PodeJsonResponse -Value $result
            }
        }
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Step'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = $Id
        Content       = $Content
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'Step')
        IsDynamic     = ($null -ne $ScriptBlock)
    }
}

function Set-PodeWebBreadcrumb {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable[]]
        $Items = @()
    )

    if (($null -eq $Items)) {
        $Items = @()
    }

    if (!(Test-PodeWebContent -Content $Items -ComponentType Element -ObjectType BreadcrumbItem)) {
        throw 'A Breadcrumb can only contain breadcrumb item elements'
    }

    $foundActive = $false
    foreach ($item in $Items) {
        if ($foundActive -and $item.Active) {
            throw 'Cannot have two active breadcrumb items'
        }

        $foundActive = $item.Active
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Breadcrumb'
        Items         = $Items
        NoEvents      = $true
    }
}

function New-PodeWebBreadcrumbItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [switch]
        $Active
    )

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Breadcrumb-Item'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        Url           = (Add-PodeWebAppPath -Url $Url)
        Active        = $Active.IsPresent
        NoEvents      = $true
    }
}

function New-PodeWebAccordion {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Bellows,

        [Parameter()]
        [int]
        $CycleInterval = 15,

        [Parameter()]
        [ValidateSet('Normal', 'Collapsed', 'Expanded')]
        [string]
        $Mode = 'Normal',

        [switch]
        $Cycle
    )

    if (!(Test-PodeWebContent -Content $Bellows -ComponentType Element -ObjectType Bellow)) {
        throw 'An Accordion can only contain Bellow elements'
    }

    if ($CycleInterval -lt 10) {
        $CycleInterval = 10
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Accordion'
        ID            = (Get-PodeWebElementId -Tag Accordion -Id $Id -Name $Name)
        Name          = $Name
        Bellows       = $Bellows
        Mode          = $Mode
        Cycle         = @{
            Enabled  = $Cycle.IsPresent
            Interval = ($CycleInterval * 1000)
        }
    }
}

function New-PodeWebBellow {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [hashtable[]]
        $Content,

        [Parameter()]
        [object]
        $Icon
    )

    if (!(Test-PodeWebContent -Content $Content -ComponentType Element)) {
        throw 'A Bellow can only contain other elements'
    }

    return @{
        Operation     = 'New'
        ComponentType = 'Element'
        ObjectType    = 'Bellow'
        Name          = $Name
        DisplayName   = (Protect-PodeWebValue -Value $DisplayName -Default $Name -Encode)
        ID            = (Get-PodeWebElementId -Tag Bellow -Id $Id -Name $Name)
        Content       = $Content
        Icon          = (Protect-PodeWebIconType -Icon $Icon -Element 'Bellow')
    }
}