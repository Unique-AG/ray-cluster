#!/bin/bash

# Check if two arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <chart-name> <oci-repo-path>"
    exit 1
fi

# Assign arguments to variables
CHART_NAME=$1
OCI_REPO_PATH=$2

# Package the Helm chart
echo "Packaging Helm chart: $CHART_NAME"
helm package $CHART_NAME

# Get the packaged chart file name
PACKAGE_NAME=$(ls ${CHART_NAME}-*.tgz)

# Push the chart to the OCI registry
echo "Pushing $PACKAGE_NAME to $OCI_REPO_PATH"
helm push $PACKAGE_NAME $OCI_REPO_PATH

# Check if the push was successful
if [ $? -eq 0 ]; then
    echo "Successfully pushed $PACKAGE_NAME to $OCI_REPO_PATH"
    
    # Remove the tarball
    echo "Removing tarball: $PACKAGE_NAME"
    rm $PACKAGE_NAME
else
    echo "Failed to push $PACKAGE_NAME to $OCI_REPO_PATH"
    exit 1
fi

echo "Process completed successfully"