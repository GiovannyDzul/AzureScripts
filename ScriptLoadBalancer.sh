#!/bin/bash

# Script para crear un entorno con alta disponibilidad

# Referenciado de: 
# https://github.com/aminespinoza/ContenidoIaaS/tree/master/AltaDisponibilidad
# https://github.com/aminespinoza/ContenidoIaaS/blob/master/AltaDisponibilidad/cloud-init.txt

# En resumen, se crean 2 VM con servidor web nginx y un balanceo de cargas para que se repartan las solicitudes. 

Num=GroupCoresa$RANDOM

# 1. Crear un grupo de recursos donde se encontrarán las VM

az group create --name $Num --location eastus

# 2. Crear una dirección IP Publica

az network public-ip create --resource-group $Num --name publicIPCoresa

# 3. Crear un balanceador de cargas

az network lb create --resource-group $Num --name loadBCoresa --frontend-ip-name frontEndCoresa --backend-pool-name backEndCoresa --public-ip-address publicIPCoresa

# 4. Crear una sonda para revisar el estado del balanceador de cargas

az network lb probe create --resource-group $Num --lb-name loadBCoresa --name healthCoresa --protocol tcp --port 80

# 5. Crear una regla de puertos en red para permitir el acceso al puerto 80 (Puerto utilizado por el servidor web Nginx)

az network lb rule create --resource-group $Num --lb-name loadBCoresa --name ruleLBPort80 --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name frontEndCoresa --backend-pool-name backEndCoresa --probe-name healthCoresa

# 6. Crear una red virtual

az network vnet create --resource-group $Num --name vNetCoresa --subnet-name vSubnetCoresa

# 7. Crear un grupo de seguridad de red

az network nsg create --resource-group $Num --name netSecGCoresa

# 8. Crear una regla en el grupo de seguridad de red

az network nsg rule create --resource-group $Num --nsg-name netSecGCoresa --name ruleSGPort80 --priority 1001 --protocol tcp --destination-port-range 80

# 9. Con un ciclo for, se crea 3 interfaces de red

for i in `seq 1 2`; do
    az network nic create \
        --resource-group $Num \
        --name vNet$i \
        --vnet-name vNetCoresa \
        --subnet vSubnetCoresa \
        --network-security-group netSecGCoresa \
        --lb-name loadBCoresa \
        --lb-address-pools backEndCoresa
done

# 10. Crear un conjunto de disponibilidad

az vm availability-set create --resource-group $Num --name avalSetCoresa

# 11. Con un ciclo for, se crea 3 VM 

for i in `seq 1 2`; do
    az vm create \
        --resource-group $Num \
        --name myVM$i \
        --availability-set avalSetCoresa \
        --nics vNet$i \
        --image UbuntuLTS \
        --size Standard_D2as_v4 \
        --location eastus \
        --public-ip-sku Standard \
        --admin-username azureuser \
        --generate-ssh-keys \
        --custom-data cloud-init.txt
done

# 12. Obtener la IP Publica para abrir desde el navegador

az network public-ip show --resource-group $Num --name publicIPCoresa --query [ipAddress] --output tsv
