$gitrepo="https://github.com/Azure-Samples/app-service-web-dotnet-get-started.git"
$webappname="PacktWebApp"

# First connect to your Azure Account.
Connect-AzureRmAccount

# Select the subscription to deploy the App to.
Select-AzureRmSubscription -SubscriptionName <yourSubscriptionName>

# Create the web app.
New-AzureRmWebApp -Name $webappname -Location "Central US" -AppServicePlan PacktAppServicePlan -ResourceGroupName PacktAppServicePlan

# Configure GitHub deployment from your GitHub repo and deploy once.
$PropertiesObject = @{
    repoUrl = "$gitrepo";
    branch = "master";
    isManualIntegration = "true";
}
Set-AzureRmResource -PropertyObject $PropertiesObject -ResourceGroupName PacktAppServicePlan -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName $webappname/web -ApiVersion 2015-08-01 -Force