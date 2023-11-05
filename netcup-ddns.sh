#!/bin/bash
# --------------------------------
# DynDNS-Script for usage with a Netcup-domain using the Netcup CCP API
# --------------------------------

# Enter your API Key here:
apikey=""
# Enter your API Password here:
apipassword=""
# Enter your Customer Number here:
customernumber=""
# Enter your domain here:
domain=""
# Enter your desired hostname here (or "@" for your root domain):
hostname=""

# -------------------------------- #
### Do Not Edit After This Line! ###
# -------------------------------- #

# One-Time check for root so we can make the log file
if [ ! -f /var/log/ddns.log ]; then
        if [ "$EUID" -ne 0 ]; then
                echo "You need to run the script as root."
                exit
        else
                touch /var/log/ddns.log
                chmod 666 /var/log/ddns.log

        fi
fi

# Netcup Endpoint URL
apiurl="https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON"

# generate Request ID:
REQID=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')

# Check if hostname is @; change variable accordingly
if [ $hostname == @ ]; then
        HOSTNAMEDOT=""
else
        HOSTNAMEDOT=$hostname.
fi

# first we need to check if our IP has changed at all, quit if IP is still identical
# <--------------------------------

# Unfortunately we need to ping a server to tell us our IPv4, F to Privacy :(
IP4=$(curl https://wanip4.unraid.net)
# Call current A Record for logging purposes
CURIP4=$(dig a $HOSTNAMEDOT$domain @root-dns.netcup.net +short)

# for IPv6 we can just ask our system :)
IP6=$(ip -6 addr show dev eno1 scope global | awk -F '[ \t]+|/' '$3 == "::1" { next;} $3 ~ /^fd00::/ { next ; } /inet6/ {print $3} ')

# Call current AAAA Record
CURIP6=$(dig aaaa $HOSTNAMEDOT$domain @root-dns.netcup.net +short)

# now we check if at least one of our IPs changed by using our existing DNS record
# and quit if thats the case
if [ $CURIP4 == $IP4 ]; then
        if [ $CURIP6 == $IP6 ]; then
#       printf %s [$(date +%s)]" " >> /var/log/ddns.log
#       echo "no change detected." >> /var/log/ddns.log
        exit 0
        fi
fi

# --------------------------------->
# now we need to acquire a session token
APISESSION=$(curl -X POST "$apiurl" -H "Content-Type: application/json" -d '{"action":"login","param":{"customernumber":"'"$customernumber"'","apikey":"'"$apikey"'","apipassword":"'"$apipassword"'","clientrequestid":"'"$REQID"'"}}' -s | jq -r .responsedata.apisessionid)

# and we need to know the hidden id of the dns records we want to change
DNSID4=$(curl -X POST "$apiurl" -H "Content-Type: application/json" -d '{"action":"infoDnsRecords","param":{"apikey":"'"$apikey"'","apisessionid":"'"$APISESSION"'","customernumber":"'"$customernumber"'","domainname":"'"$domain"'","clientrequestid":"'"$REQID"'"}}' -s | jq --arg hostname "$hostname" -r '.responsedata.dnsrecords[] | select(.hostname==$hostname) | select(.type=="A") | .id')

DNSID6=$(curl -X POST "$apiurl" -H "Content-Type: application/json" -d '{"action":"infoDnsRecords","param":{"apikey":"'"$apikey"'","apisessionid":"'"$APISESSION"'","customernumber":"'"$customernumber"'","domainname":"'"$domain"'","clientrequestid":"'"$REQID"'"}}' -s | jq --arg hostname "$hostname" -r '.responsedata.dnsrecords[] | select(.hostname==$hostname) | select(.type=="AAAA") | .id')

# Time to actually change the record here:
# <----------------------------------
#
# for IPv4
printf %s [$(date +"%d.%m.%y")" " $(date +"%H:%M:%S")]" ("$REQID") " >> /var/log/ddns.log

curl -X POST "$apiurl" -H "Content-Type: application/json" -d '{"action":"updateDnsRecords","param":{"apikey":"'"$apikey"'","apisessionid":"'"$APISESSION"'","customernumber":"'"$customernumber"'","domainname":"'"$domain"'","clientrequestid":"'"$REQID"'","dnsrecordset":{"dnsrecords":[ {"id": "'"$DNSID4"'", "hostname": "'"$hostname"'", "type": "A", "destination": "'"$IP4"'", "deleterecord": "false"}]}}}' -s | jq -r '.status, .shortmessage' | tr '\n' ' ' | sed 's/ /: /' >> /var/log/ddns.log

# If the command fails, no IPs are needed for logging
if [ $(tail -n 1 /var/log/ddns.log | grep 'error' | wc -l) == 1 ]; then
        echo >> /var/log/ddns.log
else
        echo "from $CURIP4 to $IP4 (IPv4)" >> /var/log/ddns.log
fi

# for IPv6 too
printf %s [$(date +"%d.%m.%y")" " $(date +"%H:%M:%S")]" ("$REQID") " >> /var/log/ddns.log

curl -X POST "$apiurl" -H "Content-Type: application/json" -d '{"action":"updateDnsRecords","param":{"apikey":"'"$apikey"'","apisessionid":"'"$APISESSION"'","customernumber":"'"$customernumber"'","domainname":"'"$domain"'","clientrequestid":"'"$REQID"'","dnsrecordset":{"dnsrecords":[ {"id": "'"$DNSID6"'", "hostname": "'"$hostname"'", "type": "AAAA", "destination": "'"$IP6"'", "deleterecord": "false"}]}}}' -s | jq -r '.status, .shortmessage' | tr '\n' ' ' | sed 's/ /: /' >> /var/log/ddns.log

if [ $(tail -n 1 /var/log/ddns.log | grep 'error' | wc -l) == 1 ]; then
        echo >> /var/log/ddns.log
else
        echo "from $CURIP6 to $IP6 (IPv6)" >> /var/log/ddns.log
fi
# ----------------------------------->
#
# logout session afterwards
curl -X POST "$apiurl" -H "Content-Type: application/json" -d '{"action":"logout","param":{"customernumber":"'"$customernumber"'","apikey":"'"$apikey"'","apisessionid":"'"$APISESSION"'","clientrequestid":"'"$REQID"'"}}' -s
