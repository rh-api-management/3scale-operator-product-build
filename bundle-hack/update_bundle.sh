#!/usr/bin/env bash

# TODO: verify below format is correct.
export BACKEND_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/apisonator@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"
export APICAST_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/apicast-gateway@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"
export SYSTEM_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/porta@sha256:d08d7d6c98d1b922c50aa9dbb3ee636a41abb989c00e4d39eaf4b85c168cf034"
export ZYNC_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/zync@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"
export SEARCHD_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/searchd@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"

# TODO: verify how to have these updated
#MEMCACHED_IMAGE="registry.redhat.io/rhel9/memcached@${CI_REGISTRY_MEMCACHED_DIGEST}"
#REDIS_6_IMAGE="registry.redhat.io/rhel8/redis-6@${CI_REGISTRY_REDIS_6_DIGEST}"
#MYSQL_8_IMAGE="registry.redhat.io/rhel8/mysql-80@${CI_REGISTRY_MYSQL_8_DIGEST}"
#POSTGRESQL_10_IMAGE="registry.redhat.io/rhscl/postgresql-10-rhel7@${CI_REGISTRY_POSTGRESQL_10_DIGEST}"
#OC_CLI_IMAGE="registry.redhat.io/openshift4/ose-cli@${CI_REGISTRY_OSE_CLI_4_11_DIGEST}"
#- name: RELATED_IMAGE_SYSTEM_MEMCACHED
#  value: memcached:1.5
#- name: RELATED_IMAGE_BACKEND_REDIS
#  value: quay.io/fedora/redis-6:latest
#- name: RELATED_IMAGE_SYSTEM_REDIS
#  value: quay.io/fedora/redis-6:latest
#- name: RELATED_IMAGE_SYSTEM_MYSQL
#  value: quay.io/sclorg/mysql-80-c8s
#- name: RELATED_IMAGE_SYSTEM_POSTGRESQL
#  value: quay.io/sclorg/postgresql-10-c8s
#- name: RELATED_IMAGE_ZYNC_POSTGRESQL
#  value: quay.io/sclorg/postgresql-10-c8s
#- name: RELATED_IMAGE_OC_CLI
#  value: quay.io/openshift/origin-cli:4.7
#- name: RELATED_IMAGE_SYSTEM_SEARCHD
#  value: quay.io/3scale/searchd:latest

export 3SCALE_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/3scale-prod-tenant/threescale-operator@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"

export CSV_FILE=/manifests/3scale-operator.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale/3scale-operator:latest|\"${BACKEND_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/apisonator:latest|\"${BACKEND_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/apicast:latest|\"${APICAST_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/porta:latest|\"${SYSTEM_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/zync:latest|\"${ZYNC_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/searchd:latest|\"${SEARCHD_IMAGE_PULLSPEC}\"|g" \
	-e "s|memcached:.*|\"${MEMCACHED_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/3scale-operator:v.*|\"${3SCALE_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

export AMD64_BUILT=$(skopeo inspect --raw docker://${3SCALE_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${3SCALE_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${3SCALE_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${3SCALE_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

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
csv_manifest['metadata']['annotations']['containerImage'] = os.getenv('3SCALE_OPERATOR_IMAGE_PULLSPEC', '')

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
   {'name': '3scale-operator', 'image': os.getenv('3SCALE_OPERATOR_IMAGE_PULLSPEC')}
]

dump_manifest(os.getenv('CSV_FILE'), csv_manifest)
CSV_UPDATE

cat $CSV_FILE