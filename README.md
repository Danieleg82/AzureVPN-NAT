**Azure VPN Gateway with NAT rules – MicroHack**

Table of contents

- Introduction

- Challenge 1: Build VPN tunnel and apply Static NAT rules

- Challenge 2: Convert to Dynamic NAT rules to the connection

- Challenge 3: NAT rules impact on BGP advertisements

**Introduction**

Azure VPN NAT (Network Address Translation) supports overlapping address spaces between customers on-premises branch networks and their Azure Virtual Networks. NAT can also enable business-to-business connectivity where address spaces are managed by different organizations and re-numbering networks is not possible.

In this MicroHack we will explore the Azure VPN NAT features in its most common scenario, so when Azure VNET address ranges overlap with onprem-connected network segments.

We will cover the differences between Static and Dynamic NAT modes with relevant benefits and limitations, including the possible network configurations for HUB&amp;Spoke topologies for diversified NAT approaches.

**Challenge 1: Build VPN tunnel and apply Static NAT rules**

In this first part, we will build a basic environment composed as per the following diagram:

![](RackMultipart20220324-4-60kjve_html_5ca616f4c803e791.png)

A first VNET will emulate an onprem branch to be connected to Azure side.

A second VNET will be the real Azure environment, hosting our VPN Gateway solution with NAT rules.

We will build an IPSEC tunnel between the environments, with BGP enabled, we will configure **Static** NAT rules on our VPN Gateway, and we will create a successful communication between 2 VMs with same private IP over the tunnel.

The Azure-side traffic will be seen by onprem as originated from network range 100.0.1.0/24

The Onprem-side traffic will be seen by Azure as originated from network range 100.0.2.0/24

**TASK 1 – Create the basic environment**

To create the basic environment, please run the following terraform deployment script:

_XXXXXX_

_Instructions for GitHub deployment_

_Launch Main.tf_

_XXXXXX_

This will take around 20 minutes to complete to accommodate the time to deploy VNET Gateway

As soon as it&#39;s completed, you will be in the following conditions:

- An Azure VNET with a VNET-Gateway installed but not configured with any connection or NAT rule
- An Onprem site (emulated with a VNET with overlapping IP space) with a Cisco CSR router deployed but not configured
- 2 VMs deployed – 1 in Azure 1 Onprem – sharing same IP address
- NSGs deployed to core subnets on both sides, and already pre-configured with the needed security rules for granting final connectivity purposes

_Note:_ For accessing the CSR and the VMs you will need to configure JIT access at VM level (the VMs have a public IP mapped, the JIT request will provide accessibility over SSH to the deployments)

Next steps after deployment will be to

1. Program VPN Gateway with relevant Connection object and Static NAT rules
2. Program CSR router and UDRs at Onprem side to drive NATted traffic from Azure toward CSR itself
3. Test the connectivity between AzureVM and OnpremVM

**TASK 2 – Configure Gateway Connection and NAT rules**

As first step we need to proceed with the creation of a **LocalNetworkGateway** representing our BGP-enabled Onprem segment, a **Connection** object and the **Static NAT rules** we want to apply.

_LNG_

$RG = &quot;VPNGWNATRG&quot;

$Location = &quot;West Europe&quot;

$GWName = &quot;AzureGW&quot;

$CSRPublicIP = Get-AzPublicIpAddress -Name CSRVIP -ResourceGroupName $RG

$LNG = New-AzLocalNetworkGateway -Name OnpremLNG -ResourceGroupName $RG `

-Location $Location -GatewayIpAddress $CSRPublicIP.ipAddress -BgpPeeringAddress &#39;192.168.1.1&#39; -Asn 65001

_NAT rules_

$VPNGW = Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RG

$egressnatrule = New-AzVirtualNetworkGatewayNatRule -Name &quot;EgressRule&quot; -Type &quot;Static&quot; -Mode &quot;EgressSnat&quot; -InternalMapping @(&quot;10.0.1.0/24&quot;) -ExternalMapping @(&quot;100.0.1.0/24&quot;)

$ingressnatrule = New-AzVirtualNetworkGatewayNatRule -Name &quot;IngressRule&quot; -Type &quot;Static&quot; -Mode &quot;IngressSnat&quot; -InternalMapping @(&quot;10.0.1.0/24&quot;) -ExternalMapping @(&quot;100.0.2.0/24&quot;)

Set-AzVirtualNetworkGateway -VirtualNetworkGateway $VPNGW -NatRule $ingressnatrule,$egressnatrule -BgpRouteTranslationForNat $true

_Connection_

New-AzVirtualNetworkGatewayConnection -Name Connection -ResourceGroupName $RG -Location $Location -VirtualNetworkGateway1 $VPNGW -LocalNetworkGateway2 $LNG -ConnectionType IPsec -EnableBgp $true -ConnectionProtocol IKEv2 -SharedKey &#39;MyVPNConnection1!&#39; -IngressNatRule $ingressnatrule -EgressNatRule $egressnatrule

**TASK 3 – Configure Cisco and UDRs**

Acquire JIT access to your Cisco CSR deployment – if needed – or create dedicated security rules in the NSG bound to the external subnet of the CSR (CSRExternalSubnet) to grant SSH connectivity from your public IP.

    admin\_username =&quot;LabAdmin&quot;

    admin\_password =&quot;VPNGWNAT!&quot;

SSH to the CSR:

Go to command prompt and type:

ssh LabAdmin@CSRPublicIP

Once connected to the CSR, enter config mode:

_Conf t_

Apply the following configuration script, paste in below configuration one block at a time, make sure to replace _VPNGWPublicIP_ with the IP of your VPN gateway:

_crypto ikev2 proposal Azure-Ikev2-Proposal_

_encryption aes-cbc-256_

_integrity sha1 sha256_

_group 2_

_!_

_crypto ikev2 policy Azure-Ikev2-Policy_

_match address local 10.0.3.4_

_proposal Azure-Ikev2-Proposal_

_!_

_crypto ikev2 keyring to-onprem-keyring_

_peer \&lt;VPNGWPublicIP\&gt;_

_address \&lt;VPNGWPublicIP\&gt;_

_pre-shared-key MyVPNConnection1!_

_!_

_crypto ikev2 profile Azure-Ikev2-Profile_

_match address local 10.0.3.4_

_match identity remote address \&lt;VPNGWPublicIP\&gt;_

_authentication remote pre-share_

_authentication local pre-share_

_keyring local to-onprem-keyring_

_lifetime 28800_

_dpd 10 5 on-demand_

_!_

_crypto ipsec transform-set to-Azure-TransformSet esp-gcm 256_

_mode tunnel_

_!_

_crypto ipsec profile to-Azure-IPsecProfile_

_set transform-set to-Azure-TransformSet_

_set ikev2-profile Azure-Ikev2-Profile_

_!_

_interface Loopback1_

_ip address 192.168.1.1 255.255.255.255_

_!_

_interface Tunnel1_

_ip address 10.0.3.10 255.255.255.255_

_ip tcp adjust-mss 1350_

_tunnel source 10.0.3.4_

_tunnel mode ipsec ipv4_

_tunnel destination \&lt;VPNGWPublicIP\&gt;_

_tunnel protection ipsec profile to-Azure-IPsecProfile_

_!_

_router bgp 65001_

_bgp router-id 192.168.1.1_

_bgp log-neighbor-changes_

_neighbor 10.0.2.254 remote-as 65600_

_neighbor 10.0.2.254 ebgp-multihop 255_

_neighbor 10.0.2.254 update-source Loopback1_

_!_

_address-family ipv4_

_neighbor 10.0.2.254 activate_

_network 10.0.1.0 mask 255.255.255.0_

_exit-address-family_

_!_

_!Static route to Azure BGP peer IP_

_ip route 10.0.2.254 255.255.255.255 Tunnel1_

_!Static route to internal workload subnet_

_ip route 10.0.1.0 255.255.255.0 10.0.10.1_

Type _Exit_ or hit CTRL+Z to exit configurator, then type

_Wr_

Validate the status of the IKEv2 tunnel:

_Show crypto ikev2 sa_

![](RackMultipart20220324-4-60kjve_html_94c395b734278b08.png)

Validate status of the IPSEC security associations

_Show crypto ipsec sa_

![](RackMultipart20220324-4-60kjve_html_7e3b34ef92e1a2e0.png)

![](RackMultipart20220324-4-60kjve_html_37fa87c8cab287c0.png)

![](RackMultipart20220324-4-60kjve_html_6d67700f23ab04f9.png)

Validate Tunnel interface status in general

_Show int Tunnel1_

![](RackMultipart20220324-4-60kjve_html_a9ac4f8d5ac8343.png)

Now validate the status of BGP peering between VNET Gateway and CSR:

_Show ip bgp summary_

![](RackMultipart20220324-4-60kjve_html_a657cd739b58945c.png)

_Show ip bgp_

![](RackMultipart20220324-4-60kjve_html_fbcee295c06758c2.png)

Note the routes CSR is receiving from VNET Gateway:

Gateway is advertising 2 routes  a generic 10.0.0.0/16 one and the specific one related with our EgressNAT range (100.0.1.0/24)

An integration with **Azure Route Server** in our emulated onprem environment would allow to avoid any static route configuration on that side, but this is out of scope here, so in order to create appropriate routing from the Onprem VM back to Azure we need to configure a UDR mapped to Onprem VM subnet:

$RG = &quot;VPNGWNATRG&quot;

$Location = &quot;West Europe&quot;

$OnpremRT = New-AzRouteTable `

  -Name &#39;OnpremRT&#39; `

  -ResourceGroupName $RG `

  -location $Location

  Get-AzRouteTable `

  -ResourceGroupName $RG  `

  -Name &#39;OnpremRT&#39; `

  | Add-AzRouteConfig `

  -Name &quot;ToAzure&quot; `

  -AddressPrefix 100.0.0.0/16 `

  -NextHopType &quot;VirtualAppliance&quot; `

  -NextHopIpAddress 10.0.10.4 `

 | Set-AzRouteTable

Get-AzVirtualNetwork -Name &#39;OnpremVNET&#39; -ResourceGroupName $RG | Set-azvirtualnetworksubnetConfig -Name &#39;Subnet1&#39; -AddressPrefix 10.0.1.0/24 -RouteTable $OnpremRT | set-AzVirtualNetwork

Now check the IPSEC &amp; BGP connectivity status from VPN Gateway side:

![](RackMultipart20220324-4-60kjve_html_163c12f927fe790e.png)

![](RackMultipart20220324-4-60kjve_html_cb6392e574d37c83.png)

Note how VPN Gateway is ignoring the route received from CSR since it&#39;s already covered by its own internal network-rule for the NATted range 100.0.2.0/24

Any IP range advertised by a remote branch which is overlapping with IngressNAT rules&#39; InternalMapping will be dropped by GW, which will leverage static Network routes configured via NAT.

Any advertised range which is NOT overlapping with the NAT rules definitions, will be installed as it is.

**IMPORTANT NOTE:** the NAT concept cannot be applied to the Azure VNET Gateway subnet itself or to the BGP peer IP

[https://docs.microsoft.com/en-us/azure/vpn-gateway/nat-overview#routing](https://docs.microsoft.com/en-us/azure/vpn-gateway/nat-overview#routing)

BGP peer IP address consideration for a NAT&#39;ed on-premises network:

- APIPA (169.254.0.1 to 169.254.255.254) address: NAT is not supported with BGP APIPA addresses.
- Non-APIPA address: Exclude the BGP Peer IP addresses from the NAT range.

**TASK 4 – Test VMs connectivity**

Connect to both _AzureVM_ and _OnpremVM_ via SSH after a JIT request or NSG configuration.

From AzureVM side, run:

_Ping 100.0.2.4_

![](RackMultipart20220324-4-60kjve_html_14763b059725400.png)

From OnpremVM side, run:

_Sudo tcpdump icmp -n_

_ **Question:** _ What&#39;s the source IP generating ICMP requests seen by OnpremVM?

Now ping in the opposite direction, and check again which source IP is seen to generate traffic.

**Challenge 2: Convert to Dynamic NAT rules to the connection**

When using Dynamic NAT rules, an IP address can be translated to different target IP addresses and TCP/UDP port based on availability, or with a different combination of IP address and TCP/UDP port. The latter is also called NAPT, Network Address and Port Translation.

Dynamic rules will result in stateful translation mappings depending on the traffic flows at any given time. Due to the nature of Dynamic NAT and the ever changing IP/Port combinations, flows that make use of Dynamic NAT rules have to be initiated from the  **InternalMapping**  (Pre-NAT) IP Range. The dynamic mapping is released once the flow is disconnected or gracefully terminated.

If the target address pool size is the same as the original address pool, use static NAT rule to define a 1:1 mapping in a sequential order. If the target address pool is smaller than the original address pool, use dynamic NAT rule to accommodate the differences.

In this challenge we will modify the VPN NAT rule approach to use Dynamic NAT in the direction from Azure to Onprem (EgressNAT).

When using Dynamic NAT approach, one fundamental thing to be considered is that the connection can be **unidirectional only.**

If Dynamic NAT is applied as EgressNAT, only Azure side will be able to initiate connections toward onprem.

**Task1 – modify NAT rules to Dynamic**

As first step we will disassociate existing EgressNAT rules from our connection:

$RG = &quot;VPNGWNATRG&quot;

$GWName = &quot;AzureGW&quot;

$VPNGW = Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RG

$connection = Get-AzVirtualNetworkGatewayConnection -Name Connection -ResourceGroupName $RG

$connection.EgressNatRules = $null

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection -Force

The StaticNAT rules will be kept in order to grant connectivity with the remote overlapping range, but the traffic from Azure side will be linked to a single /32 egressing address.

We will now create an Egress Dynamic NAT rule linking traffic from Azure side to a single /32 egressing address, and associate it to our VPN Gateway:

$GWIPconfig= $VPNGW.IpConfigurations.id

$Dynamicegressnatrule = New-AzVirtualNetworkGatewayNatRule -Name &quot;DynamicEgressRule&quot; -Type &quot;Dynamic&quot; -IpConfigurationId $GWIPconfig -Mode &quot;EgressSnat&quot; -InternalMapping @(&quot;10.0.1.0/24&quot;) -ExternalMapping @(&quot;100.0.1.15/32&quot;)

Set-AzVirtualNetworkGateway -VirtualNetworkGateway $VPNGW -NatRule $Dynamicegressnatrule -BgpRouteTranslationForNat $true

We will finally link the new NAT rule to the existing VPN connection:

$Dynamicegressnatrule = Get-AzVirtualNetworkGatewayNatRule -ResourceGroupName $RG -Name &quot;DynamicEgressRule&quot; -ParentResourceName $GWName

$connection.EgressNatRules = $Dynamicegressnatrule

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection -Force

**Task2 – Test VMs connectivity**

Connect to both _AzureVM_ and _OnpremVM_ via SSH after a JIT request or NSG configuration.

From AzureVM side, run:

_Ping 100.0.2.4_

![](RackMultipart20220324-4-60kjve_html_4bf0bd4805de0597.png)

From OnpremVM side, run:

_Sudo tcpdump icmp -n_

**Question:** What&#39;s the source IP generating ICMP requests seen by OnpremVM?

**Task3 – Test traffic from another source VM**

We will now proceed generating traffic toward same destination (OnpremVM) but from a different Azure resource.

Let&#39;s deploy a new Azure linux VM in the same subnet used for AzureVM:

_XXXXXX_

_Instructions for GitHub deployment_

_Launch DeployVM.tf_

_XXXXXX_

Configure JIT on the new VM (AzureVM2) and connect to it.

![](RackMultipart20220324-4-60kjve_html_e3614ca9647243db.png)

Now run:

_Ping 100.0.2.4_

Connect back to OnpremVM (make sure that TCPDUMP is still running on it, and that PING is still running as well from AzureVM)

**Question** : Do we see any ICMP traffic on OnpreVM generated by any host !=100.0.1.15 ?

**Challenge 3: NAT rules impact on BGP advertisements**

As we&#39;ve seen in Challenge1, Azure VPN Gateway is basically dropping any routes advertised by remote branch, if overlapping exists between the InternalMapping of the relevant IngressNAT rules and the what is advertised.

Goal of the next challenge will be to evaluate the impact of advertisement of BGP ranges which are not overlapping with NAT rules mappings, and to demonstrate how the whole routing is not impacted by NAT rules associated with a connection, in the case when the connection is used for traffic between non-overlapping resources.

**Task1 – Configuration of the new Onprem address range**

To demonstrate this, we will emulate a non overlapping IP on the Onprem side.

We will add a new address-space to the Onprem VNET and we&#39;ll create a subnet + VM in it.

The goal will be to connect AzureVM with OnpremVM2

![](RackMultipart20220324-4-60kjve_html_43889ac59ebb4dfa.png)

Let&#39;s start adding an extra address space to our onprem network:

$RG=&quot;VPNGWNATRG&quot;

$Location=&quot;West Europe&quot;

$VNET=Get-AzVirtualNetwork-NameOnpremVNET-ResourceGroupName$RG

$VNET.AddressSpace.AddressPrefixes.Add(&quot;192.168.25.0/24&quot;)

Set-AzVirtualNetwork-VirtualNetwork$VNET

Let&#39;s then proceed with the creation of an extra subnet (and relevant NSG) in this new address range + a VM:

_XXXXXX_

_Instructions for GitHub deployment_

_Challenge3.tf_

_XXXXXX_

Now we associate to the new Subnet2 the same UDR as Subnet1, for static redirection of AzureVNET traffic via IPSEC tunnel

$RG=&quot;VPNGWNATRG&quot;

$Location=&quot;West Europe&quot;

$OnpremRT=Get-AzRouteTable-ResourceGroupName$RG-NameOnpremRT

Get-AzVirtualNetwork-Name&#39;OnpremVNET&#39;-ResourceGroupName$RG|Set-azvirtualnetworksubnetConfig-Name&#39;Subnet2&#39;-AddressPrefix192.168.25.0/24-RouteTable$OnpremRT|set-AzVirtualNetwork

**Task2 – Configuration of the CSR BGP advertisement**

Now we need to make sure CSR starts advertising the new non-overlapping range to Azure VPN gateway.

To do so, let&#39;s connect to CSR and run:

_Conf t_

Then:

_router bgp 65001_

_address-family ipv4_

_network 192.168.25.0 mask 255.255.255.0_

_exit-address-family_

_ip route 192.168.25.0 255.255.255.0 10.0.10.1_

Check the new advertised routes from CSR side:

sh bgp neighbors 10.0.2.254 advertised-routes

![](RackMultipart20220324-4-60kjve_html_59b3a8c0d1c98c26.png)

Check that the new route is effectively seen at VPN gateway side:

![](RackMultipart20220324-4-60kjve_html_af835b65df21869b.png)

No NAT implemented for such route, as expected.

In the NIC effective routes of VM &quot;AzureVM&quot; and &quot;AzureVM2&quot; we can now see Azure VPN Gateway set as nexthop for the considered network range:

![](RackMultipart20220324-4-60kjve_html_26241da35a7fe9fd.png)

**Task3 – Validate connectivity**

Let&#39;s finally proceed validating the effective connectivity between AzureVM and OnpremVM2 over a non-NATted destination IP range.

Connect via SSH to both AzureVM and OnpremVM2 (configure JIT access or NSG security rules if needed).

From AzureVM, start a PING toward OnpremVM2:

_Ping 192.168.25.4_

![](RackMultipart20220324-4-60kjve_html_81c76dcb70a7b0fc.png)

From OnpremVM2, run:

_Sudo tcpdump -n icmp_

**Question:** Which source IP is seen by OnpremVM2 for this ICMP traffic?

**CONCLUSIONS:**

Whit this microhack I wanted to show the potential of Azure VPN Gateway&#39;s Static and Dynamic NAT rules, and how they can be leveraged in the ever-green scenario of overlapping network ranges between Azure virtual networks and VPN-connected branches.
