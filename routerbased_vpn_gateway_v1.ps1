# ------------------
# Script creates a RouterBased VPN Gateway
# Uses native Azure certificate authentication with PPP Windows client 
# 
# ver.1.11
# Author: Martin Eckeroth
#
# SETUP
$VNetName  = "VNetData"
$FESubName = "FrontEnd"
$BESubName = "Backend"
$GWSubName = "GatewaySubnet"
$VNetPrefix1 = "192.168.0.0/16"
$VNetPrefix2 = "10.254.0.0/16"
$FESubPrefix = "192.168.1.0/24"
$BESubPrefix = "10.254.1.0/24"
$GWSubPrefix = "192.168.200.0/26"
$VPNClientAddressPool = "172.16.201.0/24"
$ResourceGroup = "VpnGatewayDemo"
$Location = "North Europe"
$GWName = "VNetDataGW"
$GWIPName = "VNetDataGWPIP"
$GWIPconfName = "gwipconf"

# CONFIGURE A VIRTUAL NETWORK
New-AzResourceGroup -Name $ResourceGroup -Location $Location

$fesub = New-AzVirtualNetworkSubnetConfig -Name $FESubName -AddressPrefix $FESubPrefix
$besub = New-AzVirtualNetworkSubnetConfig -Name $BESubName -AddressPrefix $BESubPrefix
$gwsub = New-AzVirtualNetworkSubnetConfig -Name $GWSubName -AddressPrefix $GWSubPrefix

New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroup -Location $Location -AddressPrefix $VNetPrefix1,$VNetPrefix2 -Subnet $fesub, $besub, $gwsub -DnsServer 10.2.1.3

$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $GWSubName -VirtualNetwork $vnet

$pip = New-AzPublicIpAddress -Name $GWIPName -ResourceGroupName $ResourceGroup -Location $Location -AllocationMethod Dynamic
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName -Subnet $subnet -PublicIpAddress $pip

# CREATE THE VPN GATEWAY
#	GatewayType must be Vpn
#	VpnType must be RouteBased
New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $ResourceGroup `
-Location $Location -IpConfigurations $ipconf -GatewayType Vpn `
-VpnType RouteBased -EnableBgp $false -GatewaySku VpnGw1 -VpnClientProtocol "IKEv2"

# ADD THE VPN CLIENT ADDRESS POOL
$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $ResourceGroup -Name $GWName
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway -VpnClientAddressPool $VPNClientAddressPool

# GENERATE A CLIENT CERTIFICATE
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" `
-Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# EXPORT CERTIFICATE PUBLIC KEY
