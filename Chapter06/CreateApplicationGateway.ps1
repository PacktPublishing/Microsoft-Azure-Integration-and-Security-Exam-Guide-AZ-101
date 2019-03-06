# First connect to your Azure Account.
Connect-AzureRmAccount

# Select the subscription to deploy the App to.
Select-AzureRmSubscription -SubscriptionName <yourSubscriptionName>

#Create a new resource group
New-AzureRmResourceGroup -Name PacktApplicationGateway -Location eastus

#Create the network resources
#Create the subnets
$PacktAGSubnet = New-AzureRmVirtualNetworkSubnetConfig `
  -Name PacktAGSubnet `  -AddressPrefix 10.0.1.0/24
$PacktBackendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name PacktBackendSubnetConfig `
  -AddressPrefix 10.0.2.0/24

#Create the VNet 
New-AzureRmVirtualNetwork `
  -ResourceGroupName PacktApplicationGateway `
  -Location eastus `
  -Name PacktVNet `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $PacktAGSubnet, $PacktBackendSubnetConfig

#Create the public IP address
New-AzureRmPublicIpAddress `
  -ResourceGroupName PacktApplicationGateway `
  -Location eastus `
  -Name PacktAGPublicIPAddress `
  -AllocationMethod Dynamic


#Create the VMs
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName PacktApplicationGateway -Name PacktVNet
$cred = Get-Credential
for ($i=1; $i -le 2; $i++)
{
# Create a virtual machine
  $nic = New-AzureRmNetworkInterface `
    -Name PacktNic$i `
    -ResourceGroupName PacktApplicationGateway `    -Location eastus `
    -SubnetId $vnet.Subnets[1].Id
  $vm = New-AzureRmVMConfig `
    -VMName PacktVM$i `
    -VMSize Standard_D2
  $vm = Set-AzureRmVMOperatingSystem `
    -VM $vm `
    -Windows `
    -ComputerName PAcktVM$i `
    -Credential $cred `
    -ProvisionVMAgent
  $vm = Set-AzureRmVMSourceImage `
    -VM $vm `
    -PublisherName MicrosoftWindowsServer `
    -Offer WindowsServer `
    -Skus 2016-Datacenter `
    -Version latest
  $vm = Add-AzureRmVMNetworkInterface `
    -VM $vm `
    -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics `
    -VM $vm `
    -Disable

  New-AzureRmVM -ResourceGroupName PacktApplicationGateway -Location eastus -VM $vm 
  Set-AzureRmVMExtension `
    -ResourceGroupName PacktApplicationGateway `
    -ExtensionName IIS `
    -VMName PacktVM$i `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.4 `
    -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' `
    -Location EastUS
}


#Create the IP configurations and frontend port
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName PacktApplicationGateway -Name PacktVNet
$pip = Get-AzureRmPublicIPAddress -ResourceGroupName PacktApplicationGateway -Name PacktAGPublicIPAddress
$subnet= $vnet.Subnets[0]
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration `
  -Name PacktAGIPConfig `
  -Subnet $subnet
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig `
  -Name PacktAGFrontendIPConfig `
  -PublicIPAddress $pip
$frontendport = New-AzureRmApplicationGatewayFrontendPort `
  -Name PacktFrontendPort `
  -Port 80

#Create the backend pool
$address1 = Get-AzureRmNetworkInterface -ResourceGroupName PacktApplicationGateway -Name PacktNic1
$address2 = Get-AzureRmNetworkInterface -ResourceGroupName PacktApplicationGateway -Name PacktNic2

$backendPool = New-AzureRmApplicationGatewayBackendAddressPool `
  -Name PacktGBackendPool `
  -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
  -Name PacktPoolSettings `
  -Port 80 `
  -Protocol Http `
  -CookieBasedAffinity Enabled `
  -RequestTimeout 120

#Create the listener and add a rule
$defaultlistener = New-AzureRmApplicationGatewayHttpListener `
  -Name PacktAGListener `
  -Protocol Http `
  -FrontendIPConfiguration $fipconfig `
  -FrontendPort $frontendport
$frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule `
  -Name rule1 `
  -RuleType Basic `
  -HttpListener $defaultlistener `
  -BackendAddressPool $backendPool `
  -BackendHttpSettings $poolSettings


#Create the Application Gateway
$sku = New-AzureRmApplicationGatewaySku -Name Standard_Medium -Tier Standard -Capacity 2

New-AzureRmApplicationGateway `
  -Name PacktAppGateway `
  -ResourceGroupName PacktApplicationGateway `
  -Location eastus `
  -BackendAddressPools $backendPool `
  -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig `
  -GatewayIpConfigurations $gipconfig `
  -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener `
  -RequestRoutingRules $frontendRule `
  -Sku $sku


#Retrieve the public IP Address of the Application Gateway
Get-AzureRmPublicIPAddress -ResourceGroupName PacktApplicationGateway -Name PacktAGPublicIPAddress