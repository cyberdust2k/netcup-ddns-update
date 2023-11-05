# netcup-ddns-update
DynDNS-Script for usage with a Netcup-domain using the Netcup CCP API

# usage
At the top of the script are variables you need to fill to access the Netcup API and also according to which part of your DNS you want to upgrade. Further documentation will follow at a later date.

I recommend running a cronjob or a systemd-service housing this script every 30 minutes to update your IP timely, but without spamming the API endpoints unnecessarily.
