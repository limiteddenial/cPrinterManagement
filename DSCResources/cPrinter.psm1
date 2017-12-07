enum Ensure {
    Absent
    Present
}
enum PortType {
    TCPIP
    LPR
    PaperCut
}
[DscResource()]
class cPrinter {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)] 
    [System.String]$Name

    [DscProperty(Mandatory)]
    [System.String] $PortName

    [DscProperty()]
    [PortType] $PortType = [PortType]::TCPIP

    [DscProperty()]
    [System.String] $Address

    [DscProperty()]
    [System.String] $DriverName

    [DscProperty()]
    [System.Boolean] $Shared

    [DscProperty()]
    [System.String] $PermissionSDDL
    
    [DscProperty()]
    [System.Boolean] $SNMPEnabled

    [DscProperty()]
    [System.String] $SNMPCommunity

    [DscProperty()]
    [System.String] $SNMPIndex

    [DscProperty()]
    [System.String] $lprQueueName

    hidden $Messages = ""

    cPrinter(){
        $this.Messages = (Import-LocalizedData  -FileName 'cPrinterManagement.strings.psd1' -BaseDirectory (Split-Path -Parent (Split-Path -Parent $PSCOMMANDPATH)))
    }

    [void] Set(){
        $printer = Get-Printer -Name $this.Name -Full -ErrorAction SilentlyContinue
        $printerPort = Get-PrinterPort -Name $this.PortName -ErrorAction SilentlyContinue
        if($this.Ensure -eq [Ensure]::Present){
            if($null -eq $printerPort){
                Write-Verbose -Message "Creating new Printer Port"
                $PrinterPortParamaters = @{
                    Name = $this.PortName
                    PrinterHostAddress =  "local.test"
                }
                Add-PrinterPort @PrinterPortParamaters
            }
            if($null -eq $printer){
                $PrinterParamaters = @{
                    Name = $this.Name
                    PortName = $this.PortName
                    DriverName = $this.DriverName
                }
                Add-Printer @PrinterParamaters
            }
        } else {
            if($null -ne $printer){
                $PrinterParamaters = @{
                    Name = $this.Name
                }
                if($null -ne (Get-PrintJob -PrinterName $this.Name)) {
                    Get-PrintJob -PrinterName $this.Name | Remove-PrintJob
                }
                Remove-Printer @PrinterParamaters
            }
            if($null -ne $printerPort){
                try {
                    Remove-PrinterPort -Name $this.PortName
                } catch {
                    Restart-Service -Name Spooler -Force
                    Remove-PrinterPort -Name $this.PortName
                }
            }
        }
    }
    [bool] Test() {
        try {
            $printer = Get-Printer -Name $this.Name -Full
        } catch {
            $printer = $null
        }
        try {
            $printerPort = Get-PrinterPort -Name $this.PortName
        } catch {
            $printerPort = $null
        }
        if($this.Ensure -eq [Ensure]::Present){
            # region test current printer settings
            if($null -eq $printer){
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "Ensure","Absent",$this.Ensure)
                return $false
            } # End Printer
            if($null -eq $printerPort){
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "PrinterPort","Absent",$this.Ensure)
                return $false
            } # End PrinterPort
            if($this.PortName -ne $printer.PortName){
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "PortName",$printer.PortName,$this.PortName)
                return $false
            } # End PortName
            switch ($printerPort.Description) {
                "PaperCut TCP/IP Port" {  
                    try {
                        #To get Papercut address you need to look at the registry key
                        $currentAddress = (Get-Item ("HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\PaperCut TCP/IP Port\Ports\{0}" -f $this.PortName) | Get-ItemProperty).HostName                    
                    } catch {
                        $currentAddress = $null
                    }
                    if($this.Address -ne $currentAddress) {
                        Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "Address",$currentAddress,$this.Address)
                        return $false
                    } # End Address
                } # End PaperCut TCP/IP Port
                Default {
                    if($this.Address -ne $printerPort.PrinterHostAddress){
                        Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "Address",$printerPort.PrinterHostAddress,$this.Address)
                        return $false
                    } # End Address
                    if($this.SNMPEnabled -ne $printerPort.SNMPEnabled){
                        Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "SNMPEnabled",$printer.SNMPEnabled,$this.SNMPEnabled)
                        return $false
                    } # End SNMPEnabled
                    if($this.SNMPEnabled -eq $true){ 
                        if($this.SNMPCommunity -ne $printerPort.SNMPCommunity){
                            Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "SNMPCommunity",$printer.SNMPCommunity,$this.SNMPCommunity)
                            return $false
                        } # End SNMPCommunity
                        if($this.SNMPIndex -ne $printerPort.SNMPIndex){
                            Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "SNMPIndex",$printer.SNMPIndex,$this.SNMPIndex)
                            return $false
                        } # End SNMPIndex
                    } # End SNMPEnabled True
                    if($this.lprQueueName -ne $printerPort.lprQueueName){
                        Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "lprQueueName",$printer.lprQueueName,$this.lprQueueName)
                        return $false
                    } # End lprQueueName
                } # End Default
            } # End Switch
            if ($null -ne $this.DriverName -and $this.DriverName -ne $printer.DriverName) {
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "DriverName",$printer.DriverName,$this.DriverName)
                return $false
            } # End DriverName
            if ($null -ne $this.PermissionSDDL -and $this.PermissionSDDL -ne $printer.PermissionSDDL) {
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "PermissionSDDL",$printer.PermissionSDDL,$this.PermissionSDDL)
                return $false
            } # End PermissionSDDL
            if($this.Shared.GetType().Name -eq 'Boolean' -and $this.Shared -ne $printer.Shared){
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "Shared",$printer.Shared,$this.Shared)
                return $false
            } # End Shared
            # All the conditions have been met so we will return true so the set() method doesn't get called as everyting is in a desired state. 
            return $true
        } else {
            if($null -ne $printer){
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "Ensure","Present",$this.Ensure)
                return $false
            } # End Printer
            if($null -ne $printerPort){
                Write-Verbose -Message  ($this.Messages.NotInDesiredState -f "PrinterPort","Present",$this.Ensure)
                return $false
            } # End PrinterPort
            return $true
        } # End Ensure
    } # End Test()
    [cPrinter] Get(){ 
        $ReturnObject = [cPrinter]::new()
        # Gathering the printer properties
        try {
            $printer = Get-Printer -Name $this.Name -Full
        } catch {
            $ReturnObject.Ensure = [Ensure]::Absent
            return $ReturnObject
        } 
        try {
            $printerPort = Get-PrinterPort -Name $this.PortName
        } catch {
            $ReturnObject.Ensure = [Ensure]::Absent
            return $ReturnObject
        } 
        # Both the printer and the printer port were found so we are going to set Ensure to Present
        $ReturnObject.Ensure = [Ensure]::Present
        if($null -ne $printer){ 
            $ReturnObject.Name = $printer.Name
            $ReturnObject.DriverName = $printer.DriverName
            $ReturnObject.Shared = $printer.Shared
            $ReturnObject.PermissionSDDL = $printer.PermissionSDDL
        } # End Printer
        if($null -ne $printerPort){
            $ReturnObject.PortName = $printerPort.Name
            switch ($printerPort.Description) {
                "PaperCut TCP/IP Port" {  
                    try {
                        #To get Papercut address you need to look at the registry key
                        $ReturnObject.Address = (Get-Item ("HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\PaperCut TCP/IP Port\Ports\{0}" -f $this.PortName) | Get-ItemProperty).HostName                    
                    } catch {
                        $ReturnObject.Address = $null
                    }
                    #SNMP is disabled on papercut ports
                    $ReturnObject.SNMPEnabled = $false
                    $ReturnObject.SNMPCommunity = $null
                    $ReturnObject.SNMPIndex = $null
                    $ReturnObject.PortType = [PortType]::PaperCut
                } # End PaperCut TCP/IP Port
                Default {
                    $ReturnObject.Address = $printerPort.PrinterHostAddress
                    $ReturnObject.SNMPEnabled = $printerPort.SNMPEnabled
                    $ReturnObject.SNMPCommunity = $printerPort.SNMPCommunity
                    $ReturnObject.SNMPIndex = $printerPort.SNMPIndex
                    $ReturnObject.PortType = [PortType]::TCPIP
                    if($printerPort.lprQueueName){
                        $ReturnObject.lprQueueName = $printerPort.lprQueueName
                        $ReturnObject.PortType = [PortType]::LPR
                    } 
                } # End Default
            } # End Switch
        } # End PrinterPort
        return $ReturnObject
    } # End GET()
} # End Class
