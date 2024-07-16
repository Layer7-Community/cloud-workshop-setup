#!/bin/bash
# This is an example that works with Google Cloud DNS.
# 1. Check if the DNS record exists, update or create
# 2. Wait for the propagation
echo "---------------------------------------------------"
echo "---------------------------------------------------"
echo "updating dns"
echo "***************************************************"

ingressHostPostfix=
dnsServiceAccount=cloud-dns-sa@slipstream-222523.iam.gserviceaccount.com
dnsProject=slipstream-222523
jaegerHost=jaeger$ingressHostPostfix.brcmlabs.com
grafanaHost=grafana$ingressHostPostfix.brcmlabs.com
kibanaHost=kibana$ingressHostPostfix.brcmlabs.com
chartmuseumHost=charts$ingressHostPostfix.brcmlabs.com
hazelcastMancenterHost=mancenter-dev$ingressHostPostfix.brcmlabs.com
devGatewayHost=mydevgw.brcmlabs.com
prodGatewayHost=myprodgw.brcmlabs.com
otkGatewayHost=otk.brcmlabs.com
otkGatewayPMHost=pm-otk.brcmlabs.com

gcloud config set disable_prompts true >/dev/null 2>&1
gcloud config set account $dnsServiceAccount >/dev/null 2>&1
gcloud config set project $dnsProject >/dev/null 2>&1

gcloud dns record-sets transaction start --zone=brcmlabs



jaegerARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$jaegerHost 2>/dev/null)
grafanaARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$grafanaHost 2>/dev/null)
kibanaARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$kibanaHost 2>/dev/null)
devGatewayARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$devGatewayHost 2>/dev/null)
prodGatewayARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$prodGatewayHost 2>/dev/null)
otkGatewayARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$otkGatewayHost 2>/dev/null)
otkGatewayPMARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$otkGatewayPMHost 2>/dev/null)
chartMuseumARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$chartmuseumHost 2>/dev/null)
hazelcastMancenterARecord=$(gcloud dns record-sets list --zone=brcmlabs --name=$hazelcastMancenterHost 2>/dev/null)

if [[ -z ${jaegerARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$jaegerHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $jaegerHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${grafanaARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$grafanaHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $grafanaHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${kibanaARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$kibanaHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $kibanaHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${devGatewayARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$devGatewayHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $devGatewayHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${prodGatewayARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$prodGatewayHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $prodGatewayHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${otkGatewayARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$otkGatewayHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $otkGatewayHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${otkGatewayPMARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$otkGatewayPMHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $otkGatewayPMHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${chartMuseumARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$chartmuseumHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $chartmuseumHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

if [[ -z ${hazelcastMancenterARecord} ]]; then
    gcloud dns record-sets transaction add $ingressAddress --name=$hazelcastMancenterHost --ttl=300 --type=A --zone=brcmlabs
else
    gcloud dns record-sets update $hazelcastMancenterHost --rrdatas=$ingressAddress --ttl=300 --type=A --zone=brcmlabs
fi

gcloud dns record-sets transaction execute --zone=brcmlabs  2>/dev/null

echo "---------------------------------------------------"
echo "---------------------------------------------------"
echo "waiting for DNS propagation"
echo "***************************************************"
hostsResolve=false

while [ "${hostsResolve}" = "false" ]; do
    
    jaegerResolve=$(dig $jaegerHost +short)
    grafanaResolve=$(dig $grafanaHost +short)
    kibanaResolve=$(dig $kibanaHost +short)
    devGatewayResolve=$(dig $devGatewayHost +short)
    prodGatewayResolve=$(dig $prodGatewayHost +short)
    otkGatewayResolve=$(dig $otkGatewayHost +short)
    otkPMGatewayResolve=$(dig $otkGatewayPMHost +short)
    chartmuseumResolve=$(dig $chartmuseumHost +short)
    hazelcastMancenterResolve=$(dig $hazelcastMancenterHost +short)

    if [[ $jaegerResolve == $ingressAddress ]] && [[ $grafanaResolve == $ingressAddress ]] && [[ $kibanaResolve == $ingressAddress ]] && [[ $devGatewayResolve == $ingressAddress ]] && [[ $chartmuseumResolve == $ingressAddress ]] && [[ $hazelcastMancenterResolve == $ingressAddress ]] && [[ $otkGatewayResolve == $ingressAddress ]] && [[ $otkPMGatewayResolve == $ingressAddress ]] && [[ $prodGatewayResolve == $ingressAddress ]]; then
        echo "all hosts resolve"
        hostsResolve=true
        break
    fi
    sleep 10
done
echo "***************************************************"