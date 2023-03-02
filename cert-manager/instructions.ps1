https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/#part-2

#Variables
$aksName        = "NAME_OF_AKS_CLUSTER"
$aksRg          = "NAME_OF_AKS_RESOURCE_GROUP"
$aksResourcesRg = "NAME_OF_RESOURCE_GROUP_WHERE_AKS_CREATES_ITS_RESOURCES"
$miName         = "NAME_OF_MANAGED_IDENTITY"
$dnsZone        = "NAME_OF_DNS_ZONE"

#Add OIDC + workload identity extensions
az extension add --name aks-preview
az extension update -n aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableWorkloadIdentityPreview')].{Name:name,State:properties.state}"
az aks update --name $aksName --resource-group $aksRg --enable-oidc-issuer --enable-workload-identity

#Installing cert manager
helm upgrade cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --install --values D:\_playground\_misc\cert-manager-values.yaml
#check changes:
kubectl describe pod -n cert-manager -l app.kubernetes.io/component=controller
#create MI
az identity create --name $miName --resource-group $aksResourcesRg
#get MI ID
$miClientId=$(az identity show --name $miName --resource-group  $aksResourcesRg --query 'clientId' -o tsv)

#!!!!! Replace miClientId in cluster_issuer.yaml clientID: property
#role assignment for DNS zone
az role assignment create --role "DNS Zone Contributor" --assignee $miClientId --scope $(az network dns zone show -g $aksResourcesRg --name $dnsZone -o tsv --query id)

#add federated identity
$saName="cert-manager"
$saNamespace="cert-manager"
$subject="system:serviceaccount:" + $saNamespace + ":" + $saName

$saIssuer=$(az aks show --resource-group shikki-rg --name shikki-aks --query "oidcIssuerProfile.issuerUrl" -o tsv)
az identity federated-credential create --name "cert-manager" -g $aksResourcesRg --identity-name $miName --issuer $saIssuer --subject $subject
#apply cluster issuer
kubectl apply -f D:\_playground\azDo_rzidarescupersonal\Tools\cert-manager\cluster_issuer.yaml
kubectl describe clusterissuer letsencrypt-production

#make changes to Ingress Object + Values file