#!/usr/bin/env bash

# enables strict mode: `-e` fails if error, `-u` checks variable references, `-o pipefail`: prevents errors in a pipeline from being masked
set -euo pipefail

export BACKEND_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/apisonator@sha256:af6defac45e66b010b75bfcafac54ff7656eb0acfb60f84d682cbd2a5737f253"
export APICAST_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/apicast-gateway@sha256:de202ee9c78ae42a8a315563f8257295b4c97402dae72adad93375cdb2196ed7"
export SYSTEM_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/porta@sha256:5ca5224d3c27689ebd1634400438c8a65e47fcd0549aeb74819ed46e7aecde53"
export ZYNC_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/zync@sha256:bf3d99b1a6b845802b53d1067d9b866d3688efcc1f90a6e791f78111c1d14c8e"
export SEARCHD_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/searchd@sha256:010fe292d7500b426852627a63ebb2e7720cb7383d4d958a6d6b7fb2619a1aa6"

# non-3scale dependencies
#TODO: automate updates of these with renovate
# renovate: datasource=docker versioning=docker
export MEMCACHED_IMAGE_PULLSPEC="registry.redhat.io/rhel9/memcached@sha256:63fde5fa8eec0d05e182c1ee52287a20846f5dddbdcfe2a6cd308860adb3984a"
# renovate: datasource=docker versioning=docker
export REDIS_IMAGE_PULLSPEC="registry.redhat.io/rhel8/redis-6@sha256:bb24ede28ec4cd2e416f6e299ee16531d8bc0a7496d3e44ac7619d9b09366737"
# renovate: datasource=docker versioning=docker
export MYSQL_IMAGE_PULLSPEC="registry.redhat.io/rhel8/mysql-80@sha256:f6a3025d463b7763ef78ed6cce8f3f053a661a8a506e67839c98e7d9882bdf21"
# renovate: datasource=docker versioning=docker
export POSTGRESQL_IMAGE_PULLSPEC="registry.redhat.io/rhscl/postgresql-10-rhel7@sha256:a95d09fc3b224f550dec3de3d23fd2dbfc0a220dc869b4ad9559ee2f85327daa"
# renovate: datasource=docker versioning=docker
export OC_CLI_IMAGE_PULLSPEC="registry.redhat.io/openshift4/ose-cli@sha256:d2323a0294225b275d7d221da41d653c098185290ecafb723494e2833316493c"

export OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/threescale-operator@sha256:30784d3f5d9afc8d5f62a22327796e58914b012b90d5a123d6d658db5a590646"

export CSV_FILE=/manifests/3scale-operator.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale/3scale-operator:latest|\"${OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/3scale-operator:master|\"${OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/apisonator:latest|\"${BACKEND_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/apicast:latest|\"${APICAST_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/porta:latest|\"${SYSTEM_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/zync:latest|\"${ZYNC_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/searchd:latest|\"${SEARCHD_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/fedora/redis-6:latest|\"${REDIS_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/sclorg/mysql-80-c8s|\"${MYSQL_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/sclorg/postgresql-10-c8s|\"${POSTGRESQL_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/openshift/origin-cli:4.7|\"${OC_CLI_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|memcached:.*|\"${MEMCACHED_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"

export AMD64_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
csv_manifest = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
csv_manifest['metadata']['labels'] = csv_manifest['metadata'].get('labels', {})
if os.getenv('AMD64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
if os.getenv('ARM64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
if os.getenv('PPC64LE_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
if os.getenv('S390X_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
csv_manifest['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
csv_manifest['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
csv_manifest['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
# Ensure that other annotations are accurate
csv_manifest['metadata']['annotations']['repository'] = 'https://github.com/3scale/3scale-operator'
csv_manifest['metadata']['annotations']['containerImage'] = os.getenv('OPERATOR_IMAGE_PULLSPEC', '')

__dir = os.path.dirname(os.path.abspath(__file__))

# Ensure that any parameters are properly defined in the spec if you do not want to
# put them in the CSV itself
with open(f"{__dir}/DESCRIPTION", "r") as desc_file:
    description = desc_file.read()

with open(f"{__dir}/ICON", "r") as icon_file:
    icon_data = icon_file.read()

csv_manifest['spec']['description'] = description
csv_manifest['spec']['icon'][0]['base64data'] = icon_data


# Make sure that our latest nudged references are properly configured in the spec.relatedImages
# NOTE: the names should be unique
csv_manifest['spec']['relatedImages'] = [
   {'name': '3scale-operator', 'image': os.getenv('OPERATOR_IMAGE_PULLSPEC')}
]

dump_manifest(os.getenv('CSV_FILE'), csv_manifest)
CSV_UPDATE

cat $CSV_FILE