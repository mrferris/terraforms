Creating Service Account:
    az login
    az account list
    az account set --subscription="SUBSCRIPTION_ID"
    az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID"
    
From output of this command, values map to the variables in terraform.tfvars like so:
    * appId is the client_id
    * password is the client_secret
    * tenant is the tenant_id