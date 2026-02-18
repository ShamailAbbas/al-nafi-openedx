terraform output -json | python3 -c "
import sys, json

data = json.load(sys.stdin)

def get_value(key):
    return data.get(key, {}).get('value', '')

env_content = f'''# Open edX Terraform outputs as environment variables

ELASTICSEARCH_HOST={get_value('elasticsearch_endpoint')}
ELASTICSEARCH_USERNAME={get_value('elasticsearch_master_username')}
ELASTICSEARCH_PASSWORD={get_value('elasticsearch_master_password')}
MONGODB_HOST={get_value('mongodb_endpoint')}
MONGODB_PORT={get_value('mongodb_port')}
MYSQL_PORT={get_value('mysql_port')}
MYSQL_HOST={get_value('mysql_host')}
MYSQL_DATABASE={get_value('mysql_database')}
REDIS_HOST={get_value('redis_endpoint')}
REDIS_PORT={get_value('redis_port')}
S3_STORAGE_BUCKET={get_value('storage_bucket_name')}
S3_PROFILE_IMAGE_BUCKET={get_value('profile_images_bucket_name')}
AWS_ACCESS_KEY={get_value('aws_access_key_id')}
AWS_SECERT_ACCESS_KEY={get_value('aws_secret_access_key')}
CDN_DOMAIN={get_value('cloudfront_domain_name')}
MONGODB_USERNAME={get_value('mongodb_username')}
MONGODB_PASSWORD='{get_value('mongodb_password')}'
MYSQL_USERNAME={get_value('mysql_username')}
MYSQL_PASSWORD='{get_value('mysql_password')}'
AWS_REGION={get_value('aws_region')}
CLUSTER_NAME={get_value('cluster_name')}
'''

print(env_content)
" > ../../../.env