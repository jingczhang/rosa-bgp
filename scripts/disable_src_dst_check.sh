#!/bin/bash

# Configuration Variables
TAG_KEY="bgp_router"
TAG_VALUE="true"
AWS_REGION="${1:?Usage: $0 <aws-region>}"

echo "--- Starting Src/Dst Check modification script ---"
echo "Targeting instances with tag: ${TAG_KEY}=${TAG_VALUE} in ${AWS_REGION}"

# 1. Find all running EC2 Instances matching the tag filter
# We use the filter 'tag:<Key>=<Value>' and retrieve the InstanceId.
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text
)

# Check if any instances were found
if [ -z "$INSTANCE_IDS" ]; then
    echo "No running instances found with tag ${TAG_KEY}=${TAG_VALUE}. Exiting."
    exit 0
fi

echo "Found the following instances: ${INSTANCE_IDS}"
echo "----------------------------------------------------"

# 2. Loop through each Instance ID and disable the check on the primary ENI
for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Processing instance ID: ${INSTANCE_ID}..."
    
    # Use jq (or another query) to reliably find the Primary ENI ID (DeviceIndex: 0)
    ENI_ID=$(aws ec2 describe-instances \
        --region "${AWS_REGION}" \
        --instance-ids "${INSTANCE_ID}" \
        --query 'Reservations[*].Instances[*].NetworkInterfaces[?Attachment.DeviceIndex==`0`].NetworkInterfaceId' \
        --output text
    )

    if [ -z "$ENI_ID" ]; then
        echo "WARNING: Could not find primary ENI for ${INSTANCE_ID}. Skipping."
        continue
    fi

    echo "  Primary ENI ID: ${ENI_ID}"

    # 3. Modify the Network Interface Attribute to set SourceDestCheck=false
    # We use --no-source-dest-check which is the CLI parameter for SourceDestCheck=false
    aws ec2 modify-network-interface-attribute \
        --region "${AWS_REGION}" \
        --network-interface-id "${ENI_ID}" \
        --no-source-dest-check
        
    echo "  Successfully disabled Src/Dst Check on ${ENI_ID}."
done

echo "--- Script finished. ---"
