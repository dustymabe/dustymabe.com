---
title: "Find Guest IP address using QEMU Guest Agent"
tags:
date: "2013-07-14"
published: true
---

Ever needed to find the IP address of a particular guest? Of course, the
answer is "*yes*". For the most part I have either resorted to going in
through the console of the VM to find this information or used some
nifty little script like the one described
[here](http://rwmj.wordpress.com/2010/10/26/tip-find-the-ip-address-of-a-virtual-machine/)
by Richard Jones. However, if you have [qemu Guest
Agent](http://wiki.qemu.org/Features/QAPI/GuestAgent) set up ( I covered
this briefly in a previous
[post](/2013/06/26/enabling-qemu-guest-agent-anddddd-fstrim-again/) ),
then you can just query this information using the
` guest-network-get-interfaces` qemu-ga command:\
\

```nohighlight
[root@host ~]# virsh qemu-agent-command Fedora19 \
'{"execute":"guest-network-get-interfaces"}' | python -mjson.tool 
{
  "return": [
    {
      "hardware-address": "00:00:00:00:00:00", 
      "ip-addresses": [
        {
            "ip-address": "127.0.0.1", 
            "ip-address-type": "ipv4", 
            "prefix": 8
        }, 
        {
            "ip-address": "::1", 
            "ip-address-type": "ipv6", 
            "prefix": 128
        }
      ], 
      "name": "lo"
    }, 
    {
      "hardware-address": "52:54:00:ba:4d:ef", 
      "ip-addresses": [
        {
            "ip-address": "192.168.100.136", 
            "ip-address-type": "ipv4", 
            "prefix": 24
        }, 
        {
            "ip-address": "fe80::5054:ff:feba:4def", 
            "ip-address-type": "ipv6", 
            "prefix": 64
        }
      ], 
      "name": "eth0"
    }
  ]
}
```

\
This gives us all of the information related to each network interface
of the VM. Notice that I ran the output through a JSON formatter to make
it more readable.\
\
Dusty
