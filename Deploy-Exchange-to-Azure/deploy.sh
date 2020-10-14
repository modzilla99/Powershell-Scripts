#!/bin/bash

#Checking Package-Dependencies
[[ -z "$(which az)" ]] && AZURECLI=No || AZURECLI=Yes
[[ -z "$(which jq)" ]] && PKGS="jq"
[[ -z "$(which sponge)" ]] && PKGS="${PKGS} moreutils"
[[ -z "$(which curl)" ]] && PKGS="${PKGS} curl"

[ "${AZURECLI}" == "Yes" ] && {
    [[ -e /etc/apt/sources.list.d/azure-cli.list || "$(which apt)" == "/usr/bin/apt" ]] || {
        echo "Bitte deinstalliere azure-cli! (Unsupportete Version)"
        exit 0
    }
    az account show >/dev/null 2>/dev/null || {
        echo "Bitte anmelden!"
        az login
    }

} || {
    echo "Soll die Azure-Cli installiert werden?"
    read ANSWER

    case $ANSWER in
    N | n | No | no | nein | Nein | n | N)
        echo "Dann mach es selbst ;)"
        exit 0
        ;;

    Y | y | Yes | yes | ja | Ja | j | J)

        [[ "$(sudo id -u)" == 0 ]] || {
            echo "Error elevating privilages!"
            exit 0
        }

        printf "Starte Installation..."
        sudo su -c '
                apt update >/dev/null 2>/dev/null
                env DEBIAN_FRONTEND=noninteractive apt -y install ca-certificates curl apt-transport-https lsb-release gnupg >/dev/null 2>/dev/null
                curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg
                echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list
                apt update >/dev/null 2>/dev/null
                env DEBIAN_FRONTEND=noninteractive apt install azure-cli >/dev/null 2>/dev/null
            ' && printf "Done\n"

        echo "Nun bitte im Browser anmelden!"
        az account show >/dev/null 2>/dev/null || {
            echo "Bitte anmelden!"
            az login
        }
        ;;
    esac
}

[[ -z "${PKGS}" ]] || {

    echo "Es sind nicht alle Dependencies auf dem System vorhanden, nach Eingabe des Passworts werden diese installiert!"

    if [ $(which apt) == "/usr/bin/apt" ]; then
        echo "++ apt -y install --no-install-recommends ${PKGS}"
        sudo su -c "sudo apt -y update >/dev/null && env DEBIAN_FRONTEND=noninteractive apt -y install --no-install-recommends ${PKGS} >/dev/null 2>/dev/null"

    elif [ $(which dnf) == "/usr/bin/dnf" ]; then
        sudo dnf -y install ${PKGS} >/dev/null

    elif [ $(which zypper) == "/usr/bin/zypper" ]; then
        sudo zypper -y install ${PKGS} >/dev/null
    else
        echo -e "Linux-Derivat nicht erkannt, bitte folgende Packete eigenständig installieren: ${PKGS} \n You're on your own!"
    fi
}

if [[ -d ./bin ]]; then
    [[ -e ./bin/azuredeploy.parameters.json ]] && {
        echo "Es ist bereits eine Parameter-Datei vorhanden, soll die bereits vorhandene Version deployt werden?"
        read ANSWER

        case $ANSWER in
        N | n | No | no | nein | Nein | n | N)
            rm ./bin/azuredeploy.parameters.json
            curl -SsL 'https://raw.githubusercontent.com/sredlin/Exchange2016Azure/master/azuredeploy.parameters.json' -o ./bin/azuredeploy.parameters.json
            ;;

        Y | y | Yes | yes | ja | Ja | j | J)
            echo "Wie soll die ResourceGroup gennant werden?"
            read RSG
            az group create --name ${RSG} -l westeurope
            az deployment group create -g ${RSG} --parameters ./bin/azuredeploy.parameters.json --template-uri 'https://raw.githubusercontent.com/sredlin/Exchange2016Azure/master/azuredeploy.json' --no-wait
            exit
            ;;

        *)
            echo Error
            exit 0
            ;;
        esac
    } || curl -SsL 'https://raw.githubusercontent.com/sredlin/Exchange2016Azure/master/azuredeploy.parameters.json' -o ./bin/azuredeploy.parameters.json
else
    mkdir ./bin
    curl -SsL 'https://raw.githubusercontent.com/sredlin/Exchange2016Azure/master/azuredeploy.parameters.json' -o ./bin/azuredeploy.parameters.json
fi

echo "Wie heißt der Trainee? (3-Buchstaben)?"
read TRAINEE

echo "Welchem Zweck dient das Deployment (Ausbildung/Schulung)?"
read USE

case $USE in
Ausbildung)
    DNSRSG=rg-publicdns
    PRIMDOMAIN=my-ausbildung.domain
    SUBID="c2a49ad0-a068-4fcb-9e02-ad109815957f"
    TENANTID="c2a49ad0-a068-4fcb-9e02-ad109815957f"
    APPID="c2a49ad0-a068-4fcb-9e02-ad109815957f"
    PASSWORD="e7587fd8WPC6wwo6_569670817acaoO~C"
    ;;
Schulung)
    PRIMDOMAIN=my-schulung.domain
    ;;
*)
    echo Error
    exit 1
    ;;
esac

RSG=${TRAINEE}-rsg-exchange-deployment
DOMAIN=${TRAINEE}.${PRIMDOMAIN}

WRITEBACK="sponge ./bin/azuredeploy.parameters.json"
CATAZ="cat ./bin/azuredeploy.parameters.json"

function crjson() {

    ${CATAZ} | jq "${1} = \"${2}\"" | ${WRITEBACK}

}

function crpass() {

    printf 'Bitte nun das Passwort für die VM eingeben: '
    read -s VAL && echo ''
    printf 'Bitte noch ein zweites Mal zur Verifikation: '
    read -s VAL1 && echo ''

    [[ $VAL == $VAL1 ]] || crpass

}

#Create KeyVault and Password
VLTNAME="${TRAINEE}-exc-keyvault-${RANDOM}"
SECRET="vmAdminPassword"
az group create --name ${RSG} -l westeurope
KEYVLTID=$(az keyvault create --retention-days 7 --enabled-for-template-deployment true --location westeurope --name ${VLTNAME} --resource-group ${RSG} | jq .id | cut -d'"' -f2)

crpass
az keyvault secret set --vault-name ${VLTNAME} --name $SECRET --value "$VAL" >/dev/null
unset VAL VAL1

crjson ".parameters.vmAdminPassword.reference.keyVault.id" $KEYVLTID
crjson ".parameters.vmAdminPassword.reference.secretName"  $SECRET
crjson ".parameters.trainee.value"                         $TRAINEE
crjson ".parameters.Domain.value.name"                     $USE
crjson ".parameters.Domain.value.ResourceGroup"            $DNSRSG
crjson ".parameters.Domain.value.domain"                   $PRIMDOMAIN
crjson ".parameters.SubID.value"                           $SUBID
crjson ".parameters.TenantID.value"                        $TENANTID
crjson ".parameters.AppID.value"                           $APPID
crjson ".parameters.Password.value"                        $PASSWORD

${CATAZ} | jq 'del(.parameters.exchangeStorageSizeInGB)' | ${WRITEBACK}

az deployment group create --no-wait -g ${RSG} --parameters ./bin/azuredeploy.parameters.json --template-uri 'https://raw.githubusercontent.com/modzilla99/Exchange2016Azure/master/azuredeploy.json' && echo Done || echo Error

echo "Das Deployment wird nun eine Weile in Anspruch nehmen!"
